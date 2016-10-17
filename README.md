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
let nameEventual = eventualUser.map { user in user.firstName }
nameEventual.finallyOnMainThread { name in print(name) }
```

Or chain with other async operations:

```swift
func getReposForUser(user: User) -> Eventual<[Repo]> { ... }

let eventualRepos = getUserFromInternet()
                      .flatMap { user in
                        getReposForUser(user)
                      }
```

## Convenient functions

`join`:

```swift
Eventually.join(Eventual("hi"), Eventual(23))
  .finallyOnMainThread { tuple in
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
let liftedAdd = Eventually.lift(add)
// liftedAdd is Eventual<Int>, Eventual<Int> -> Eventual<Int>
// the final value will be resolved as the addition of the two values once they resolve
```

`peek`:

This method is intended to help while testing, when you expect an `Eventual` to be resolved in a
particular way. Use of this in production code **is heavily discouraged** as it sidesteps much of
the point of the tool.

```swift
func testResolvesAfterWork() {
    let workDoer = WorkDoer()
    let eventual = workDoer.work()

    XCTAssertNil(eventual.peek())

    workDoer.finishWorking()

    XCTAssertEqual(eventual.peek(), "work finished!")
}
```

# Licensing

The MIT License (MIT)

Copyright (c) 2016 Zachary Clark

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
