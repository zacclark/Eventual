import XCTest
@testable import Eventual

class EventualTests: XCTestCase {
    
    func testPreResolvedEventuals() {
        let e = Eventual("a string")
        var expectedString: String? = nil
        e.finally { s in expectedString = s }
        XCTAssertEqual("a string", expectedString)
    }
    
    func testResolvingLater() {
        let r = Resolver<String>()
        let e = r.eventual
        
        var eventualValue: String? = nil
        e.finally { s in eventualValue = s }
        
        XCTAssertNil(eventualValue)
        
        r.resolve("hi there")
        
        XCTAssertEqual("hi there", eventualValue)
    }
    
    func testParallel() {
        let r = Resolver<String>()
        let e = r.eventual
        
        var eventualValue1: String? = nil
        var eventualValue2: String? = nil
        e.finally { s in eventualValue1 = s }
        e.finally { s in eventualValue2 = s }
        
        XCTAssertNil(eventualValue1)
        XCTAssertNil(eventualValue2)
        
        r.resolve("BOTH")
        
        XCTAssertEqual("BOTH", eventualValue1)
        XCTAssertEqual("BOTH", eventualValue2)
    }
    
    func testSimpleChaining() {
        let r = Resolver<String>()
        let e = r.eventual
        
        var eventualValue: Int? = nil
        
        let eChained = e.then { s in s.characters.count }
        eChained.finally { i in eventualValue = i }
        
        XCTAssertNil(eventualValue)
        
        r.resolve("four")
        
        XCTAssertEqual(4, eventualValue)
    }
    
    func testAdvancedChainingAkaReturningAnEventual() {
        let r = Resolver<String>()
        let e = r.eventual
        
        var eventualValue: String? = nil
        
        let eChained = e.then { _ in Eventual("could be async") }
        eChained.finally { s in eventualValue = s }
        
        XCTAssertNil(eventualValue)
        
        r.resolve("ignored")
        
        XCTAssertEqual("could be async", eventualValue)
    }
    
    func testJoin() {
        var firstJoinedValue: (String, Int)? = nil
        join(Eventual("hi"), Eventual(2)).finally { joinedValue in firstJoinedValue = joinedValue }
        
        XCTAssertEqual(firstJoinedValue?.0, "hi")
        XCTAssertEqual(firstJoinedValue?.1, 2)
        
        var secondJoinedValue: (String, Int)? = nil
        let r1 = Resolver<String>()
        let r2 = Resolver<Int>()
        join(r1.eventual, r2.eventual).finally { joinedValue in secondJoinedValue = joinedValue }
        
        XCTAssertNil(secondJoinedValue)
        
        r1.resolve("YOLO")
        
        XCTAssertNil(secondJoinedValue)
        
        r2.resolve(100)
        
        XCTAssertEqual(secondJoinedValue?.0, "YOLO")
        XCTAssertEqual(secondJoinedValue?.1, 100)
    }
    
    func testAvoidDoubleResolution() {
        let r = Resolver<String>()
        let e = r.eventual
        
        var eventualValue: String? = nil
        e.finally { s in eventualValue = s }
        
        XCTAssertNil(eventualValue)
        
        r.resolve("hi there")
        
        XCTAssertEqual("hi there", eventualValue)
        
        r.resolve("some new value")
        
        XCTAssertEqual("hi there", eventualValue)
    }
    
}
