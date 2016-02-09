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

struct Resolver<T> {
    let eventual: Eventual<T>
    
    init() {
        eventual = Eventual<T>()
    }
    
    func resolve(v: T) {
        eventual.resolve(v)
    }
}

// MARK: - Methods on eventuals

func join<T, U>(e1: Eventual<T>, _ e2: Eventual<U>) -> Eventual<(T, U)> {
    return e1.then { (tValue: T) in
        return e2.then { (uValue: U) in
            return (tValue, uValue)
        }
    }
}