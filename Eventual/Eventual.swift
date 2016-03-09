public class Eventual<T> {
    typealias Effect = T -> Void
    private var value: T?
    private var effects: [Effect]
    
    public init() {
        value = nil
        effects = []
    }
    
    public init(_ v: T) {
        value = v
        effects = []
    }
    
    private func resolve(v: T) {
        guard value == nil else {
            return
        }

        value = v
        for e in effects {
            e(v)
        }
    }
    
    private func finally(f: T -> Void) {
        if let v = self.value {
            f(v)
            return
        }
        effects.append(f)
    }
    
    public func finallyOnMainThread(f: T -> Void) {
        let mainThreadF: T -> Void = { t in
            if NSThread.isMainThread() {
                f(t)
            } else {
                NSOperationQueue.mainQueue().addOperationWithBlock({
                    f(t)
                })
            }
        }
        if let v = self.value {
            mainThreadF(v)
            return
        }
        effects.append(mainThreadF)
    }
    
    public func map<U>(f: T -> U) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            otherE.resolve(f(t))
        }
        return otherE
    }
    
    public func flatMap<U>(f: T -> Eventual<U>) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            let newE = f(t)
            newE.finally({ u in otherE.resolve(u) })
        }
        return otherE
    }
    
    public func bind<U>(f: T -> Eventual<U>) -> Eventual<U> {
        return flatMap(f)
    }
}

// MARK: - Convenience extension for simpler naming

extension Eventual {
    public func then<U>(f: T -> U) -> Eventual<U> {
        return map(f)
    }
    
    public func then<U>(f: T -> Eventual<U>) -> Eventual<U> {
        return bind(f)
    }
}

public func UnsafeGetEventualValue<T>(e: Eventual<T>) -> T? {
    return e.value
}

// MARK: - Convenience extension for forcibly delaying resolution (useful for testing)

extension Eventual {
    /// Delay resolution by some amount of seconds
    /// - parameter seconds: The amount of seconds to delay by
    /// - returns: A new Eventual with the delay applied
    public func delayedBy(seconds: Double) -> Eventual<T> {
        return self.bind { t in
            let r = Resolver<Void>()
            
            let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC)))
            dispatch_after(
                dispatchTime,
                dispatch_get_main_queue(),
                r.resolve
            )
            
            return r.eventual.map { _ in t }
        }
    }
}

// MARK: - Resolver

public struct Resolver<T> {
    public let eventual: Eventual<T>
    
    public init() {
        eventual = Eventual<T>()
    }
    
    public func resolve(v: T) {
        eventual.resolve(v)
    }
}

// MARK: - Methods on eventuals

// MARK: join

public func join<A, B>(e1: Eventual<A>, _ e2: Eventual<B>) -> Eventual<(A, B)> {
    return e1.then { (tValue: A) in e2.then { (uValue: B) in (tValue, uValue) } }
}

public func join<A, B, C>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>) -> Eventual<(A, B, C)> {
    return join(e1, e2).then { (a: A, b: B) in e3.then { c in (a, b, c) } }
}

public func join<A, B, C, D>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>) -> Eventual<(A, B, C, D)> {
    return join(e1, e2, e3).then { (a: A, b: B, c: C) in e4.then { d in (a, b, c, d) } }
}

public func join<A, B, C, D, E>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>, _ e5: Eventual<E>) -> Eventual<(A, B, C, D, E)> {
    return join(e1, e2, e3, e4).then { (a: A, b: B, c: C, d: D) in e5.then { e in (a, b, c, d, e) } }
}

// MARK: lift

public func lift<A,B>(f: A -> B) -> (Eventual<A> -> Eventual<B>) {
    return { (eA: Eventual<A>) in eA.then(f) }
}

public func lift<A,B,C>(f: (A, B) -> C) -> ((Eventual<A>, Eventual<B>) -> Eventual<C>) {
    return { (eA: Eventual<A>, eB: Eventual<B>) in join(eA, eB).then(f) }
}

public func lift<A,B,C,D>(f: (A, B, C) -> D) -> ((Eventual<A>, Eventual<B>, Eventual<C>) -> Eventual<D>) {
    return { (eA: Eventual<A>, eB: Eventual<B>, eC: Eventual<C>) in join(eA, eB, eC).then(f) }
}