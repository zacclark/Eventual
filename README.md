# Eventual

Simple implementation of an async value in swift.

## Inside your services

```swift
func getUserFromInternet() -> Eventual<User> {
  let r = Resolver<User>()
  
  networkClient.get("whatever") { json in
    // do your json -> domain object
    let user: User = userFromJSON(json)
    r.resolve(user)
  }
  
  return r.eventual
}
```

## Consuming your services

```swift
let eventualUser = getUserFromInternet()
eventualUser.finally { user in 
  // now you have a user!
}
```

**NOTE** `Eventual` does not care about threading/queuing, so you need to manage where you do work. Handlers will be called from whatever context the `Eventual` is resolved in. Need to be on the main thread after getting a value? Use one of the wealth of options in Foundation.

You can also chain without losing type safety:

```swift
let nameEventual = eventualUser.then { user in user.firstName }
nameEventual.finally { name in print(name) }
```

Or chain with other async operations:

```swift
func getReposForUser(user: User) -> Eventual<[Repo]> { ... }

let eventualRepos = getUserFromInternet().then{ user in getReposForUser(user) }
```

## Convenient functions

`join`:

```swift
join(Eventual("hi"), Eventual(23)).finally { tuple in
  print(tuple.0) // hi
  print(tuple.1) // 23
}
```

`lift`:

Convert functions from operating on concrete types to work on eventuals instead:

```swift
func add(lhs: Int, rhs: Int) -> Int {
    return lhs + rhs
}
// add is Int, Int -> Int
let liftedAdd = lift(add)
// liftedAdd is Eventual<Int>, Eventual<Int> -> Eventual<Int>
// the final value will be resolved as the addition of the two values once they resolve
```

`valueForTests`:

If you `@testable import Eventual` you can ask an `Eventual` for its value, to test resolution:

```swift
func testResolvesAfterWork() {
    let workDoer = WorkDoer()
    let eventual = workDoer.work()

    XCTAssertNil(eventual.valueForTests)

    workDoer.finishWorking()

    XCTAssertEqual(eventual.valueForTests, "work finished!")    
}
```
