// The method and functions in this file were renamed so as
// to be more in line with Swift 3 API guidelines.
//
// https://swift.org/documentation/api-design-guidelines/

extension Eventual {
    @available(*, unavailable, renamed: "delayed(by:)")
    public func delayedBy(_ seconds: Double) -> Eventual<T> {
        return delayed(by: seconds)
    }
}

// MARK: join
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
