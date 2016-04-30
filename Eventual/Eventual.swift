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
    
    /// "Peek" into the current state of the Eventual
    /// - returns: `T?` The eventual value (when resolved) or nil (when not yet resolved)
    public func peek() -> T? {
        return value
    }
}

// MARK: - Convenience extension for forcibly delaying resolution (useful for testing)

extension Eventual {
    /// Delay resolution by some amount of seconds
    /// - parameter seconds: The amount of seconds to delay by
    /// - returns: A new Eventual with the delay applied
    public func delayedBy(seconds: Double) -> Eventual<T> {
        return self.flatMap { t in
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
    return e1.flatMap { a in e2.map { b in (a,b) } }
}

public func join<A, B, C>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>) -> Eventual<(A, B, C)> {
    return join(e1, e2).flatMap { (a: A, b: B) in e3.map { c in (a, b, c) } }
}

public func join<A, B, C, D>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>) -> Eventual<(A, B, C, D)> {
    return join(e1, e2, e3).flatMap { (a: A, b: B, c: C) in e4.map { d in (a, b, c, d) } }
}

public func join<A, B, C, D, E>(e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>, _ e5: Eventual<E>) -> Eventual<(A, B, C, D, E)> {
    return join(e1, e2, e3, e4).flatMap { (a: A, b: B, c: C, d: D) in e5.map { e in (a, b, c, d, e) } }
}

// MARK: lift

public func lift<A,B>(f: A -> B) -> (Eventual<A> -> Eventual<B>) {
    return { (eA: Eventual<A>) in eA.map(f) }
}

public func lift<A,B,C>(f: (A, B) -> C) -> ((Eventual<A>, Eventual<B>) -> Eventual<C>) {
    return { (eA: Eventual<A>, eB: Eventual<B>) in join(eA, eB).map(f) }
}

public func lift<A,B,C,D>(f: (A, B, C) -> D) -> ((Eventual<A>, Eventual<B>, Eventual<C>) -> Eventual<D>) {
    return { (eA: Eventual<A>, eB: Eventual<B>, eC: Eventual<C>) in join(eA, eB, eC).map(f) }
}

// MARK: operators

infix operator >>- { associativity left precedence 100 }
/// Operator equivalent to `flatMap`
public func >>-<T,U>(lhs: Eventual<T>, rhs: T -> Eventual<U>) -> Eventual<U> {
    return lhs.flatMap(rhs)
}

// MARK: deprecated

extension Eventual {
    @available(*, deprecated, message="use map instead, it fits with swift naming conventions")
    public func then<U>(f: T -> U) -> Eventual<U> {
        return map(f)
    }

    @available(*, deprecated, message="use flatMap instead, it fits with swift naming conventions")
    public func then<U>(f: T -> Eventual<U>) -> Eventual<U> {
        return bind(f)
    }

    @available(*, deprecated, message="use flatMap instead, it fits with swift naming conventions")
    public func bind<U>(f: T -> Eventual<U>) -> Eventual<U> {
        return flatMap(f)
    }
}

@available(*, deprecated, message="use peek instead")
public func UnsafeGetEventualValue<T>(e: Eventual<T>) -> T? {
    return e.value
}
