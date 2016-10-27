public class Eventual<T> {
    typealias Effect = (T) -> Void
    fileprivate var value: T?
    fileprivate var effects: [Effect]
    
    public init() {
        value = nil
        effects = []
    }
    
    public init(_ v: T) {
        value = v
        effects = []
    }
    
    fileprivate func resolve(_ v: T) {
        guard value == nil else {
            return
        }

        value = v
        for e in effects {
            e(v)
        }
    }
    
    private func finally(_ f: @escaping (T) -> Void) {
        if let v = self.value {
            f(v)
            return
        }
        effects.append(f)
    }
    
    public func finallyOnMainThread(_ f: @escaping (T) -> Void) {
        let mainThreadF: (T) -> Void = { t in
            if Thread.isMainThread {
                f(t)
            } else {
                OperationQueue.main.addOperation { f(t) }
            }
        }
        if let v = self.value {
            mainThreadF(v)
            return
        }
        effects.append(mainThreadF)
    }
    
    public func map<U>(_ f: @escaping (T) -> U) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            otherE.resolve(f(t))
        }
        return otherE
    }
    
    public func flatMap<U>(_ f: @escaping (T) -> Eventual<U>) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            let newE = f(t)
            newE.finally { u in otherE.resolve(u) }
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
    public func delayed(by seconds: Double) -> Eventual<T> {
        return self.flatMap { t in
            let r = Resolver<Void>()
            
            let dispatchTime = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(
                deadline: dispatchTime,
                execute: r.resolve
            )
            
            return r.eventual.map { _ in t }
        }
    }

    @available(*, unavailable, renamed: "delayed(by:)")
    public func delayedBy(_ seconds: Double) -> Eventual<T> {
        return delayed(by: seconds)
    }
}

// MARK: - Resolver

public struct Resolver<T> {
    public let eventual: Eventual<T>
    
    public init() {
        eventual = Eventual<T>()
    }
    
    public func resolve(_ v: T) {
        eventual.resolve(v)
    }
}

// MARK: - Eventually

public struct Eventually {}

// MARK: join

extension Eventually {
    public static func join<A, B>(_ e1: Eventual<A>, _ e2: Eventual<B>) -> Eventual<(A, B)> {
        return e1.flatMap { (a: A) in
            e2.map { b in (a,b) }
        }
    }

    public static func join<A, B, C>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>) -> Eventual<(A, B, C)> {
        return join(e1, e2).flatMap { (a: A, b: B) in
            e3.map { c in (a, b, c) }
        }
    }

    public static func join<A, B, C, D>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>) -> Eventual<(A, B, C, D)> {
        return join(e1, e2, e3).flatMap { (a: A, b: B, c: C) in
            e4.map { d in (a, b, c, d) }
        }
    }

    public static func join<A, B, C, D, E>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>, _ e5: Eventual<E>) -> Eventual<(A, B, C, D, E)> {
        return join(e1, e2, e3, e4).flatMap { (a: A, b: B, c: C, d: D) in
            e5.map { e in (a, b, c, d, e) }
        }
    }
}

// MARK: renamed Swift 2.3 'join' functions
@available(*, unavailable, renamed: "Eventually.join")
public func join<A, B>(_ e1: Eventual<A>, _ e2: Eventual<B>) -> Eventual<(A, B)> {
    return e1.flatMap { a in e2.map { b in (a,b) } }
}

@available(*, unavailable, renamed: "Eventually.join")
public func join<A, B, C>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>) -> Eventual<(A, B, C)> {
    return Eventually.join(e1, e2).flatMap { (a: A, b: B) in e3.map { c in (a, b, c) } }
}

@available(*, unavailable, renamed: "Eventually.join")
public func join<A, B, C, D>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>) -> Eventual<(A, B, C, D)> {
    return Eventually.join(e1, e2, e3).flatMap { (a: A, b: B, c: C) in e4.map { d in (a, b, c, d) } }
}

@available(*, unavailable, renamed: "Eventually.join")
public func join<A, B, C, D, E>(_ e1: Eventual<A>, _ e2: Eventual<B>, _ e3: Eventual<C>, _ e4: Eventual<D>, _ e5: Eventual<E>) -> Eventual<(A, B, C, D, E)> {
    return Eventually.join(e1, e2, e3, e4).flatMap { (a: A, b: B, c: C, d: D) in e5.map { e in (a, b, c, d, e) } }
}


// MARK: lift

extension Eventually {
    public static func lift<A,B>(_ f: @escaping (A) -> B) -> ((Eventual<A>) -> Eventual<B>) {
        return { (eA: Eventual<A>) in
            eA.map(f)
        }
    }

    public static func lift<A,B,C>(_ f: @escaping (A, B) -> C) -> ((Eventual<A>, Eventual<B>) -> Eventual<C>) {
        return { (eA: Eventual<A>, eB: Eventual<B>) in
            join(eA, eB).map(f)
        }
    }

    public static func lift<A,B,C,D>(_ f: @escaping (A, B, C) -> D) -> ((Eventual<A>, Eventual<B>, Eventual<C>) -> Eventual<D>) {
        return { (eA: Eventual<A>, eB: Eventual<B>, eC: Eventual<C>) in
            join(eA, eB, eC).map(f)
        }
    }
}

// MARK: renamed Swift 2.3 'lift' functions
@available(*, unavailable, renamed: "Eventually.lift")
public func lift<A,B>(_ f: @escaping (A) -> B) -> ((Eventual<A>) -> Eventual<B>) {
    return { (eA: Eventual<A>) in eA.map(f) }
}

@available(*, unavailable, renamed: "Eventually.lift")
public func lift<A,B,C>(_ f: @escaping (A, B) -> C) -> ((Eventual<A>, Eventual<B>) -> Eventual<C>) {
    return { (eA: Eventual<A>, eB: Eventual<B>) in Eventually.join(eA, eB).map(f) }
}

@available(*, unavailable, renamed: "Eventually.lift")
public func lift<A,B,C,D>(_ f: @escaping (A, B, C) -> D) -> ((Eventual<A>, Eventual<B>, Eventual<C>) -> Eventual<D>) {
    return { (eA: Eventual<A>, eB: Eventual<B>, eC: Eventual<C>) in Eventually.join(eA, eB, eC).map(f) }
}

// MARK: operators

infix operator >>-: AdditionPrecedence
/// Operator equivalent to `flatMap`
public func >>-<T,U>(lhs: Eventual<T>, rhs: @escaping (T) -> Eventual<U>) -> Eventual<U> {
    return lhs.flatMap(rhs)
}
