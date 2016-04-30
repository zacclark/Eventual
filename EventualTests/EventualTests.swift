import XCTest
@testable import Eventual

class EventualTests: XCTestCase {
    
    func testPreResolvedEventuals() {
        let e = Eventual("a string")
        XCTAssertEqual(e.peek(), "a string")
    }
    
    func testResolvingLater() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(e.peek())
        
        r.resolve("hi there")
        
        XCTAssertEqual(e.peek(), "hi there")
    }
    
    func testParallel() {
        let r = Resolver<String>()
        let e1 = r.eventual
        let e2 = r.eventual
        
        XCTAssertNil(e1.peek())
        XCTAssertNil(e2.peek())
        
        r.resolve("BOTH")
        
        XCTAssertEqual("BOTH", e1.peek())
        XCTAssertEqual("BOTH", e2.peek())
    }
    
    func testSimpleChaining() {
        let r = Resolver<String>()
        let e = r.eventual
        
        let eChained = e.map { s in s.characters.count }
        
        XCTAssertNil(eChained.peek())
        
        r.resolve("four")
        
        XCTAssertEqual(4, eChained.peek())
    }
    
    func testAdvancedChainingAkaReturningAnEventual() {
        let r = Resolver<String>()
        let e = r.eventual
        
        let eChained = e.flatMap { _ in Eventual("could be async") }
        
        XCTAssertNil(eChained.peek())
        
        r.resolve("ignored")
        
        XCTAssertEqual("could be async", eChained.peek())
    }
    
    func testFlatMapOperator() {
        let r = Resolver<String>()
        let builder1 = { (string: String) in
            return Eventual("[[ \(string) ]]")
        }
        let builder2 = { (string: String) in
            return Eventual("__ \(string) __")
        }
        
        let x = r.eventual >>- builder1 >>- builder2
        
        r.resolve("*")
        
        XCTAssertEqual(x.peek(), "__ [[ * ]] __")
    }
    
    func testJoin2() {
        let joined = join(Eventual("hi"), Eventual(2))
        let firstJoinedValue: (String, Int)? = joined.peek()
        
        XCTAssertEqual(firstJoinedValue?.0, "hi")
        XCTAssertEqual(firstJoinedValue?.1, 2)
        
        let r1 = Resolver<String>()
        let r2 = Resolver<Int>()
        let joined2 = join(r1.eventual, r2.eventual)
        
        XCTAssertNil(joined2.peek())
        
        r1.resolve("YOLO")
        
        XCTAssertNil(joined2.peek())
        
        r2.resolve(100)
        
        XCTAssertEqual(joined2.peek()?.0, "YOLO")
        XCTAssertEqual(joined2.peek()?.1, 100)
    }
    
    func testJoin3() {
        let joined = join(Eventual("hi"), Eventual(2), Eventual(("Inner", "Tuple")))
        let firstJoinedValue: (String, Int, (String, String))? = joined.peek()
        
        XCTAssertEqual(firstJoinedValue?.0, "hi")
        XCTAssertEqual(firstJoinedValue?.1, 2)
        XCTAssertEqual(firstJoinedValue?.2.0, "Inner")
        XCTAssertEqual(firstJoinedValue?.2.1, "Tuple")
    }
    
    func testAvoidDoubleResolution() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(e.peek())
        
        r.resolve("hi there")
        
        XCTAssertEqual("hi there", e.peek())
        
        r.resolve("some new value")
        
        XCTAssertEqual("hi there", e.peek())
    }
    
    func testLift() {
        func characterCount(s: String) -> Int {
            return s.characters.count
        }
        
        let sEventual = Eventual("four")
        var eventualValue: Int? = nil
        
        let lifted = lift(characterCount)(sEventual)
        
        XCTAssertEqual(lifted.peek(), 4)
        
        func add(lhs: Int, rhs: Int) -> Int {
            return lhs + rhs
        }
        let liftedAdd = lift(add)
        let liftedValue = liftedAdd( Eventual(2), Eventual(3) )
        XCTAssertEqual(liftedValue.peek(), 5)
        
        func weirdThreeArg(one: String, two: Int, three: String?) -> String {
            return "\(one) - \(two * 2) - \(three ?? "(missing)")"
        }
        XCTAssertEqual(weirdThreeArg("a", two: 2, three: "b"), "a - 4 - b")
        XCTAssertEqual(weirdThreeArg("z", two: 10, three: nil), "z - 20 - (missing)")
        let liftedWeird = lift(weirdThreeArg)
        XCTAssertEqual( liftedWeird( Eventual("a"), Eventual(2), Eventual("b") ).peek()
                      , "a - 4 - b"
                      )
        XCTAssertEqual( liftedWeird( Eventual("z"), Eventual(10), Eventual(nil) ).peek()
                      , "z - 20 - (missing)"
                      )
    }
    
    func testSpecialAccessToInternalValueInTests() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(e.peek())
        
        r.resolve("hi there")
        
        XCTAssertEqual(e.peek(), "hi there")
    }
    
    func testPeek() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(e.peek())
        
        r.resolve("hi there")
        
        XCTAssertEqual(e.peek(), "hi there")
    }
    
    func testResolvingOffMainThreadWhileFinalizingOnMainThread() {
        let mainQueue = NSOperationQueue.mainQueue()
        let otherQueue = NSOperationQueue()
        
        let r = Resolver<String>()
        let e = r.eventual
        
        let expectation = self.expectationWithDescription("resolution happened")
        
        var calledOnQueue: NSOperationQueue? = nil
        var calledWithValue: String? = nil
        e.finallyOnMainThread { value in
            calledOnQueue = NSOperationQueue.currentQueue()
            calledWithValue = value
            expectation.fulfill()
        }
        
        otherQueue.addOperationWithBlock({
            r.resolve("in the background")
        })
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
        
        XCTAssertEqual(calledOnQueue, mainQueue)
        XCTAssertEqual(calledWithValue, "in the background")
    }
    
    /// To aid use in tests, here resolution might be used during test setup, it is useful to avoid any async behavior. If we're already on the main thread we won't enqueue the operation, but rather execute it immediately.
    func testResolvingOnMainThreadAndFinalizingThereImmediately() {
        let r = Resolver<String>()
        let e = r.eventual
        
        r.resolve("hi")
        
        var value: String? = nil
        e.finallyOnMainThread { v in value = v }
        
        XCTAssertEqual(value, "hi")
    }
    
}
