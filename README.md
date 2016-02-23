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
eventualUser.finallyOnMainThread { user in 
  // now you have a user!
}
```

You can also chain without losing type safety:

```swift
let nameEventual = eventualUser.then { user in user.firstName }
nameEventual.finallyOnMainThread { name in print(name) }
```

Or chain with other async operations:

```swift
func getReposForUser(user: User) -> Eventual<[Repo]> { ... }

let eventualRepos = getUserFromInternet().then{ user in getReposForUser(user) }
```

## Convenient functions

`join`:

```swift
join(Eventual("hi"), Eventual(23)).finallyOnMainThread { tuple in
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

`UnsafeGetEventualValue`:

This method is intended to help while testing, when you expect an `Eventual` to be resolved in a particular way. Use of this in production code **is heavily discouraged** as it sidesteps much of the point of the tool.

```swift
func testResolvesAfterWork() {
    let workDoer = WorkDoer()
    let eventual = workDoer.work()

    XCTAssertNil(UnsafeGetEventualValue(eventual))

    workDoer.finishWorking()

    XCTAssertEqual(UnsafeGetEventualValue(eventual), "work finished!")    
}
```
