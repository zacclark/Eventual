public class Eventual<T> {
    typealias Effect = T -> Void
    private var value: T?
    private var effects: [Effect]
    
    init() {
        value = nil
        effects = []
    }
    
    init(_ v: T) {
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
    
    func finally(f: T -> Void) {
        if let v = self.value {
            f(v)
            return
        }
        effects.append(f)
    }
    
    func map<U>(f: T -> U) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            otherE.resolve(f(t))
        }
        return otherE
    }
    
    func bind<U>(f: T -> Eventual<U>) -> Eventual<U> {
        let otherE = Eventual<U>()
        finally { t in
            let newE = f(t)
            newE.finally({ u in otherE.resolve(u) })
        }
        return otherE
    }
}

// MARK: - Convenience extenion for simpler naming

extension Eventual {
    func then<U>(f: T -> U) -> Eventual<U> {
        return map(f)
    }
    
    func then<U>(f: T -> Eventual<U>) -> Eventual<U> {
        return bind(f)
    }
}

// MARK: - Resolver

public struct Resolver<T> {
    let eventual: Eventual<T>
    
    init() {
        eventual = Eventual<T>()
    }
    
    func resolve(v: T) {
        eventual.resolve(v)
    }
}

// MARK: - Methods on eventuals

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

public func lift<A,B>(f: A -> B) -> (Eventual<A> -> Eventual<B>) {
    return { (eA: Eventual<A>) in eA.then(f) }
}