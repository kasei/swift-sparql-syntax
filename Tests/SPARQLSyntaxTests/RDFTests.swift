import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension RDFTest {
    static var allTests : [(String, (RDFTest) -> () throws -> Void)] {
        return [
            ("testConstructorDecimal", testConstructorDecimal),
            ("testConstructorDecimal2", testConstructorDecimal2),
            ("testConstructorDouble", testConstructorDouble),
            ("testConstructorDouble2", testConstructorDouble2),
            ("testConstructorDouble3", testConstructorDouble3),
            ("testConstructorFloat", testConstructorFloat),
            ("testConstructorFloat2", testConstructorFloat2),
            ("testConstructorInteger", testConstructorInteger),
            ("testDateTerms1", testDateTerms1),
            ("testDecimalRound1", testDecimalRound1),
            ("testDecimalRound2", testDecimalRound2),
            ("testQuadPattern_bindings", testQuadPattern_bindings),
            ("testQuadPattern_matches", testQuadPattern_matches),
            ("testQuadPattern_matches_shared_var", testQuadPattern_matches_shared_var),
            ("testQuadPattern_matches_shared_var_nonbinding", testQuadPattern_matches_shared_var_nonbinding),
            ("testTermJSON_Blank", testTermJSON_Blank),
            ("testTermJSON_IRI", testTermJSON_IRI),
            ("testTermJSON_LanguageLiteral", testTermJSON_LanguageLiteral),
            ("testTermJSON_SimpleLiteral", testTermJSON_SimpleLiteral),
        ]
    }
}
#endif

enum TestError: Error {
    case error
}

// swiftlint:disable type_body_length
class RDFTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testConstructorInteger() {
        let t = Term(integer: 7)
        XCTAssertEqual(t.value, "7")
    }
    
    func testConstructorDecimal() {
        let t = Term(decimal: 7.1)
        XCTAssertEqual(t.value, "7.1")
    }
    
    func testDateTerms1() throws {
        let date = Date(timeIntervalSince1970: 1559577112)
        let term1 = Term(dateTime: date, timeZone: nil)
        XCTAssertEqual(term1.value, "2019-06-03T15:51:52")
        
        guard let tz2 = TimeZone(secondsFromGMT: 3600) else {
            throw TestError.error
        }
        
        let term2 = Term(dateTime: date, timeZone: tz2)
        XCTAssertEqual(term2.value, "2019-06-03T15:51:52+01:00")

        guard let tz3 = TimeZone(secondsFromGMT: -36_000) else {
            throw TestError.error
        }
        
        let term3 = Term(dateTime: date, timeZone: tz3)
        XCTAssertEqual(term3.value, "2019-06-03T15:51:52-10:00")
    }
    
    func testDecimalRound1() {
        let t = Term(decimal: 7.1)
        let r = t.numeric!.round
        guard case .decimal(let decimalValue) = r else {
            XCTFail()
            return
        }
        XCTAssertEqual(decimalValue, 7.0)
    }
    
    func testDecimalRound2() {
        let decimal = Decimal(sign: .minus, exponent: -1, significand: 75) // -7.5
        let t = Term(decimal: decimal)
        let r = t.numeric!.round
        guard case .decimal(let decimalValue) = r else {
            XCTFail()
            return
        }
        XCTAssertEqual(decimalValue, -8.0)
    }
    
    func testConstructorDecimal2() {
        let t = Term(value: "-017.10", type: .datatype(.decimal))
        XCTAssertEqual(t.value, "-17.1")
    }
    
    func testConstructorFloat() {
        let t = Term(float: -70.1)
        XCTAssertEqual(t.value, "-7.01E1")
    }
    
    func testConstructorFloat2() {
        let t = Term(float: -0.701, exponent: 1)
        XCTAssertEqual(t.value, "-7.01E0")
    }
    
    func testConstructorDouble() {
        let t = Term(double: 700.1)
        XCTAssertEqual(t.value, "7.001E2")
    }
    
    func testConstructorDouble2() {
        let t = Term(double: 7001.0, exponent: -1)
        XCTAssertEqual(t.value, "7.001E2")
    }
    
    func testConstructorDouble3() {
        let t = Term(double: 0.00123)
        XCTAssertEqual(t.value, "1.23E-3")
    }
    
    func testTermJSON_SimpleLiteral() throws {
        let t = Term(string: "foobar")
        let e = JSONEncoder()
        let j = try e.encode(t)
        let s = String(data: j, encoding: .utf8)!
        let expected = """
            {"type":"literal","value":"foobar","datatype":"http:\\/\\/www.w3.org\\/2001\\/XMLSchema#string"}
            """
        XCTAssertEqual(s, expected)
    }
    
    func testTermJSON_LanguageLiteral() throws {
        let t = Term(value: "foobar", type: .language("en-us"))
        let e = JSONEncoder()
        let j = try e.encode(t)
        let s = String(data: j, encoding: .utf8)!
        let expected = """
            {"type":"literal","value":"foobar","xml:lang":"en-us"}
            """
        XCTAssertEqual(s, expected)
    }
    
    func testTermJSON_Blank() throws {
        let t = Term(value: "b1", type: .blank)
        let e = JSONEncoder()
        let j = try e.encode(t)
        let s = String(data: j, encoding: .utf8)!
        let expected = """
            {"type":"bnode","value":"b1"}
            """
        XCTAssertEqual(s, expected)
    }
    
    func testTermJSON_IRI() throws {
        let t = Term(iri: "https://www.w3.org/TR/sparql11-results-json/#select-encode-terms")
        let e = JSONEncoder()
        let j = try e.encode(t)
        let s = String(data: j, encoding: .utf8)!
        let expected = """
            {"type":"uri","value":"https:\\/\\/www.w3.org\\/TR\\/sparql11-results-json\\/#select-encode-terms"}
            """
        XCTAssertEqual(s, expected)
    }
    
    func testQuadPattern_matches() throws {
        let q = Quad(subject: Term(iri: "http://example.org/s"), predicate: Term.rdf("type"), object: Term(iri: "http://xmlns.com/foaf/0.1/Person"), graph: Term(iri: "http://example.org/data"))
        let qp = QuadPattern(
            subject: .variable("s", binding: true),
            predicate: .bound(Term.rdf("type")),
            object: .variable("class", binding: true),
            graph: .variable("graph", binding: true)
        )
        XCTAssertTrue(qp.matches(q))
    }
    
    func testQuadPattern_matches_shared_var() throws {
        let q1 = Quad(subject: Term(iri: "http://example.org/s"), predicate: Term.rdf("type"), object: Term(iri: "http://xmlns.com/foaf/0.1/Person"), graph: Term(iri: "http://example.org/s"))
        let q2 = Quad(subject: Term(iri: "http://example.org/s"), predicate: Term.rdf("type"), object: Term(iri: "http://xmlns.com/foaf/0.1/Person"), graph: Term(iri: "http://example.org/data"))
        let qp = QuadPattern(
            subject: .variable("s", binding: true),
            predicate: .bound(Term.rdf("type")),
            object: .variable("class", binding: true),
            graph: .variable("s", binding: true)
        )
        XCTAssertTrue(qp.matches(q1))
        XCTAssertFalse(qp.matches(q2))
    }
    
    func testQuadPattern_matches_shared_var_nonbinding() throws {
        let q2 = Quad(subject: Term(iri: "http://example.org/s"), predicate: Term.rdf("type"), object: Term(iri: "http://xmlns.com/foaf/0.1/Person"), graph: Term(iri: "http://example.org/data"))
        let qp = QuadPattern(
            subject: .variable("s", binding: true),
            predicate: .bound(Term.rdf("type")),
            object: .variable("class", binding: true),
            graph: .variable("s", binding: false)
        )
        XCTAssertTrue(qp.matches(q2))
    }
    
    func testQuadPattern_bindings() throws {
        let q2 = Quad(subject: Term(iri: "http://example.org/s"), predicate: Term.rdf("type"), object: Term(iri: "http://xmlns.com/foaf/0.1/Person"), graph: Term(iri: "http://example.org/data"))
        let qp = QuadPattern(
            subject: .variable("s", binding: true),
            predicate: .bound(Term.rdf("type")),
            object: .variable("class", binding: true),
            graph: .variable("s", binding: false)
        )
        let b = qp.bindings(for: q2)
        XCTAssertNotNil(b)
        XCTAssertEqual(b, .some([
            "s": Term(iri: "http://example.org/s"),
            "class": Term(iri: "http://xmlns.com/foaf/0.1/Person")
        ]))
    }
}
