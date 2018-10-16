import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension XSDTest {
    static var allTests : [(String, (XSDTest) -> () throws -> Void)] {
        return [
            ("testInteger", testInteger),
            ("testNegativeFloat", testNegativeFloat),
            ("testPositiveFloat", testPositiveFloat),
            ("testPositiveDouble", testPositiveDouble),
            ("testPositiveDecimal", testPositiveDecimal),
            ("testAddition", testAddition),
            ("testSubtraction", testSubtraction),
            ("testMultiplication", testMultiplication),
            ("testDivision", testDivision),
            ("testNegate", testNegate),
            ("testEquality", testEquality),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class XSDTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInteger() {
        let value = NumericValue.integer(-7)
        XCTAssertEqual(value.value, -7.0)
        XCTAssertEqual(value.absoluteValue.value, 7.0)
        XCTAssertEqual(value.round.value, -7.0)
        XCTAssertEqual(value.ceil.value, -7.0)
        XCTAssertEqual(value.floor.value, -7.0)
        XCTAssertEqual(value.term, Term(integer: -7))
        XCTAssertEqual(value.description, "-7")
    }
    
    func testNegativeFloat() {
        let value = NumericValue.float(mantissa: -35, exponent: -1)
        XCTAssertEqual(value.value, -3.5)
        XCTAssertEqual(value.absoluteValue.value, 3.5)
        XCTAssertEqual(value.round.value, -4.0)
        XCTAssertEqual(value.ceil.value, -3.0)
        XCTAssertEqual(value.floor.value, -4.0)
        XCTAssertEqual(value.term, Term(float: -3.5))
        XCTAssertEqual(value.description, "-35.0E-1f")
    }
    
    func testPositiveFloat() {
        let value = NumericValue.float(mantissa: 15, exponent: -1)
        XCTAssertEqual(value.value, 1.5)
        XCTAssertEqual(value.absoluteValue.value, 1.5)
        XCTAssertEqual(value.round.value, 2.0)
        XCTAssertEqual(value.ceil.value, 2.0)
        XCTAssertEqual(value.floor.value, 1.0)
        XCTAssertEqual(value.term, Term(float: 1.5))
        XCTAssertEqual(value.description, "15.0E-1f")
    }
    
    func testPositiveDouble() {
        let value = NumericValue.double(mantissa: 15, exponent: -1)
        XCTAssertEqual(value.value, 1.5)
        XCTAssertEqual(value.absoluteValue.value, 1.5)
        XCTAssertEqual(value.round.value, 2.0)
        XCTAssertEqual(value.ceil.value, 2.0)
        XCTAssertEqual(value.floor.value, 1.0)
        XCTAssertEqual(value.term, Term(double: 1.5))
        XCTAssertEqual(value.description, "15.0E-1d")
    }
    
    func testPositiveDecimal() {
        let value = NumericValue.decimal(Decimal(string: "1.123")!)
        XCTAssertEqual(value.value, 1.123)
        XCTAssertEqual(value.absoluteValue.value, 1.123)
        XCTAssertEqual(value.round.value, 1.0)
        XCTAssertEqual(value.ceil.value, 2.0)
        XCTAssertEqual(value.floor.value, 1.0)
        XCTAssertEqual(value.term, Term(decimal: Decimal(string: "1.123")!))
        XCTAssertEqual(value.description, "1.123")
    }
    
    func testAddition() {
        let i = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: 15, exponent: -1)
        let d = NumericValue.double(mantissa: 25, exponent: 2)
        let c = NumericValue.decimal(Decimal(string: "1.123")!)
        
        let iiValue = i + i
        if case .integer(let v) = iiValue {
            XCTAssertEqual(v, -2)
            XCTAssertEqual(iiValue.value, -2.0)
        } else {
            XCTFail()
        }
        
        let ifValue = i + f
        if case .float(_, _) = ifValue { // case let .float(m, e)
            //            XCTAssertEqual(m, 5)
            //            XCTAssertEqual(e, -1)
            XCTAssertEqual(ifValue.value, 0.5)
        } else {
            XCTFail()
        }
        
        let idValue = i + d
        if case .double(_, _) = idValue { // case let .double(m, e)
            XCTAssertEqual(idValue.value, 2499.0)
        } else {
            XCTFail()
        }
        
        let icValue = i + c
        if case .decimal(_) = icValue { // case let .decimal(d)
            XCTAssertEqual(icValue.value, 0.123)
        } else {
            XCTFail("\(icValue)")
        }
        
        let dfValue = d + f
        if case .double(_, _) = dfValue { // case let .double(m, e)
            XCTAssertEqual(dfValue.value, 2501.5)
        } else {
            XCTFail()
        }
    }

    func testSubtraction() {
        let i = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: 15, exponent: -1)
        let d = NumericValue.double(mantissa: 25, exponent: 2)
        let c = NumericValue.decimal(Decimal(string: "1.123")!)
        
        let iiValue = i - i
        if case .integer(let v) = iiValue {
            XCTAssertEqual(v, 0)
            XCTAssertEqual(iiValue.value, 0.0)
        } else {
            XCTFail()
        }
        
        let ifValue = i - f
        if case .float(_, _) = ifValue { // case let .float(m, e)
            //            XCTAssertEqual(m, 5)
            //            XCTAssertEqual(e, -1)
            XCTAssertEqual(ifValue.value, -2.5)
        } else {
            XCTFail()
        }
        
        let idValue = i - d
        if case .double(_, _) = idValue { // case let .double(m, e)
            XCTAssertEqual(idValue.value, -2501.0)
        } else {
            XCTFail()
        }
        
        let icValue = i - c
        if case .decimal(_) = icValue { // case let .decimal(d)
            XCTAssertEqual(icValue.value, -2.123, accuracy: 0.0001)
        } else {
            XCTFail("\(icValue)")
        }
        
        let dfValue = d - f
        if case .double(_, _) = dfValue { // case let .double(m, e)
            XCTAssertEqual(dfValue.value, 2498.5, accuracy: 0.0001)
        } else {
            XCTFail()
        }
    }

    func testMultiplication() {
        let i = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: 15, exponent: -1)
        let d = NumericValue.double(mantissa: 25, exponent: 2)
        let c = NumericValue.decimal(Decimal(string: "1.123")!)
        
        let iiValue = i * i
        if case .integer(let v) = iiValue {
            XCTAssertEqual(v, 1)
            XCTAssertEqual(iiValue.value, 1.0)
        } else {
            XCTFail()
        }
        
        let ifValue = i * f
        if case .float(_, _) = ifValue { // case let .float(m, e)
            //            XCTAssertEqual(m, 5)
            //            XCTAssertEqual(e, -1)
            XCTAssertEqual(ifValue.value, -1.5)
        } else {
            XCTFail()
        }
        
        let idValue = i * d
        if case .double(_, _) = idValue { // case let .double(m, e)
            XCTAssertEqual(idValue.value, -2500.0)
        } else {
            XCTFail()
        }
        
        let icValue = i * c
        if case .decimal(_) = icValue { // case let .decimal(d)
            XCTAssertEqual(icValue.value, -1.123, accuracy: 0.0001)
        } else {
            XCTFail("\(icValue)")
        }
        
        let dfValue = d * f
        if case .double(_, _) = dfValue { // case let .double(m, e)
            XCTAssertEqual(dfValue.value, 3750.0, accuracy: 0.0001)
        } else {
            XCTFail()
        }
    }

    func testDivision() {
        let i = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: 15, exponent: -1)
        let d = NumericValue.double(mantissa: 25, exponent: 2)
        let c = NumericValue.decimal(Decimal(string: "1.123")!)
        
        let iiValue = i / i
        if case .decimal(_) = iiValue {
            XCTAssertEqual(iiValue.value, 1.0, accuracy: 0.0001)
        } else {
            XCTFail()
        }
        
        let ifValue = i / f
        if case .float(_, _) = ifValue { // case let .float(m, e)
            //            XCTAssertEqual(m, 5)
            //            XCTAssertEqual(e, -1)
            XCTAssertEqual(ifValue.value, -0.6666, accuracy: 0.0001)
        } else {
            XCTFail()
        }
        
        let idValue = i / d
        if case .double(_, _) = idValue { // case let .double(m, e)
            XCTAssertEqual(idValue.value, -0.0004, accuracy: 0.0001)
        } else {
            XCTFail()
        }
        
        let icValue = i / c
        if case .decimal(_) = icValue { // case let .decimal(d)
            XCTAssertEqual(icValue.value, -0.8904, accuracy: 0.0001)
        } else {
            XCTFail("\(icValue)")
        }
        
        let dfValue = d / f
        if case .double(_, _) = dfValue { // case let .double(m, e)
            XCTAssertEqual(dfValue.value, 1666.6666, accuracy: 0.0001)
        } else {
            XCTFail()
        }
    }

    func testNegate() {
        let i = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: 15, exponent: -1)
        let d = NumericValue.double(mantissa: 25, exponent: 2)
        let c = NumericValue.decimal(Decimal(string: "1.123")!)
        
        let iValue = -i
        if case .integer(let v) = iValue {
            XCTAssertEqual(v, 1)
        } else {
            XCTFail()
        }
        
        let fValue = -f
        if case .float(_, _) = fValue { // case let .float(m, e)
            //            XCTAssertEqual(m, 5)
            //            XCTAssertEqual(e, -1)
            XCTAssertEqual(fValue.value, -1.5, accuracy: 0.1)
        } else {
            XCTFail()
        }
        
        let dValue = -d
        if case .double(_, _) = dValue { // case let .double(m, e)
            XCTAssertEqual(dValue.value, -2500.0, accuracy: 0.1)
        } else {
            XCTFail("\(dValue)")
        }
        
        let cValue = -c
        if case .decimal(_) = cValue { // case let .decimal(d)
            XCTAssertEqual(cValue.value, -1.123, accuracy: 0.001)
        } else {
            XCTFail("\(cValue)")
        }
    }

    func testEquality() {
        let i = NumericValue.integer(-1)
        let i2 = NumericValue.integer(-1)
        let f = NumericValue.float(mantissa: -1, exponent: 0)
        let d = NumericValue.double(mantissa: -1, exponent: 0)
        let c = NumericValue.decimal(Decimal(string: "-1.0")!)
        
        XCTAssertTrue(i === i)
        XCTAssertTrue(i === i2)
        XCTAssertFalse(i === f)
        XCTAssertFalse(i === d)
        XCTAssertFalse(i === c)

        XCTAssertTrue(f === f)
        XCTAssertFalse(f === d)
        XCTAssertFalse(f === c)

        XCTAssertTrue(d === d)
        XCTAssertFalse(d === c)

        XCTAssertTrue(c === c)
    }
}
