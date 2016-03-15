import XCTest
@testable import Eventual

class EventualTests: XCTestCase {
    
    func testPreResolvedEventuals() {
        let e = Eventual("a string")
        XCTAssertEqual(UnsafeGetEventualValue(e), "a string")
    }
    
    func testResolvingLater() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(UnsafeGetEventualValue(e))
        
        r.resolve("hi there")
        
        XCTAssertEqual(UnsafeGetEventualValue(e), "hi there")
    }
    
    func testParallel() {
        let r = Resolver<String>()
        let e1 = r.eventual
        let e2 = r.eventual
        
        XCTAssertNil(UnsafeGetEventualValue(e1))
        XCTAssertNil(UnsafeGetEventualValue(e2))
        
        r.resolve("BOTH")
        
        XCTAssertEqual("BOTH", UnsafeGetEventualValue(e1))
        XCTAssertEqual("BOTH", UnsafeGetEventualValue(e2))
    }
    
    func testSimpleChaining() {
        let r = Resolver<String>()
        let e = r.eventual
        
        let eChained = e.then { s in s.characters.count }
        
        XCTAssertNil(UnsafeGetEventualValue(eChained))
        
        r.resolve("four")
        
        XCTAssertEqual(4, UnsafeGetEventualValue(eChained))
    }
    
    func testAdvancedChainingAkaReturningAnEventual() {
        let r = Resolver<String>()
        let e = r.eventual
        
        let eChained = e.then { _ in Eventual("could be async") }
        
        XCTAssertNil(UnsafeGetEventualValue(eChained))
        
        r.resolve("ignored")
        
        XCTAssertEqual("could be async", UnsafeGetEventualValue(eChained))
    }
    
    func testJoin2() {
        let joined = join(Eventual("hi"), Eventual(2))
        let firstJoinedValue: (String, Int)? = UnsafeGetEventualValue(joined)
        
        XCTAssertEqual(firstJoinedValue?.0, "hi")
        XCTAssertEqual(firstJoinedValue?.1, 2)
        
        let r1 = Resolver<String>()
        let r2 = Resolver<Int>()
        let joined2 = join(r1.eventual, r2.eventual)
        
        XCTAssertNil(UnsafeGetEventualValue(joined2))
        
        r1.resolve("YOLO")
        
        XCTAssertNil(UnsafeGetEventualValue(joined2))
        
        r2.resolve(100)
        
        XCTAssertEqual(UnsafeGetEventualValue(joined2)?.0, "YOLO")
        XCTAssertEqual(UnsafeGetEventualValue(joined2)?.1, 100)
    }
    
    func testJoin3() {
        let joined = join(Eventual("hi"), Eventual(2), Eventual(("Inner", "Tuple")))
        let firstJoinedValue: (String, Int, (String, String))? = UnsafeGetEventualValue(joined)
        
        XCTAssertEqual(firstJoinedValue?.0, "hi")
        XCTAssertEqual(firstJoinedValue?.1, 2)
        XCTAssertEqual(firstJoinedValue?.2.0, "Inner")
        XCTAssertEqual(firstJoinedValue?.2.1, "Tuple")
    }
    
    func testAvoidDoubleResolution() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(UnsafeGetEventualValue(e))
        
        r.resolve("hi there")
        
        XCTAssertEqual("hi there", UnsafeGetEventualValue(e))
        
        r.resolve("some new value")
        
        XCTAssertEqual("hi there", UnsafeGetEventualValue(e))
    }
    
    func testLift() {
        func characterCount(s: String) -> Int {
            return s.characters.count
        }
        
        let sEventual = Eventual("four")
        var eventualValue: Int? = nil
        
        let lifted = lift(characterCount)(sEventual)
        
        XCTAssertEqual(UnsafeGetEventualValue(lifted), 4)
        
        func add(lhs: Int, rhs: Int) -> Int {
            return lhs + rhs
        }
        let liftedAdd = lift(add)
        let liftedValue = liftedAdd( Eventual(2), Eventual(3) )
        XCTAssertEqual(UnsafeGetEventualValue(liftedValue), 5)
        
        func weirdThreeArg(one: String, two: Int, three: String?) -> String {
            return "\(one) - \(two * 2) - \(three ?? "(missing)")"
        }
        XCTAssertEqual(weirdThreeArg("a", two: 2, three: "b"), "a - 4 - b")
        XCTAssertEqual(weirdThreeArg("z", two: 10, three: nil), "z - 20 - (missing)")
        let liftedWeird = lift(weirdThreeArg)
        XCTAssertEqual(
            UnsafeGetEventualValue(liftedWeird( Eventual("a"), Eventual(2), Eventual("b") ))
            , "a - 4 - b")
        XCTAssertEqual(
            UnsafeGetEventualValue(liftedWeird( Eventual("z"), Eventual(10), Eventual(nil) ))
            , "z - 20 - (missing)")
    }
    
    func testSpecialAccessToInternalValueInTests() {
        let r = Resolver<String>()
        let e = r.eventual
        
        XCTAssertNil(UnsafeGetEventualValue(e))
        
        r.resolve("hi there")
        
        XCTAssertEqual(UnsafeGetEventualValue(e), "hi there")
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
