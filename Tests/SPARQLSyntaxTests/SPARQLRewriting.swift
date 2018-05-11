import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension SPARQLParserTests {
    static var allTests : [(String, (SPARQLParserTest) -> () throws -> Void)] {
        return [
            ("testNodeReplacement", testNodeReplacement),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLNodeReplacementTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNodeReplacement() {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s ex:value ?o . FILTER(?o != 7.0)\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            let replaced = try a.replace(["o": Term(integer: 8)])
            let tp = TriplePattern(
                subject: .variable(".blank.b1", binding: true),
                predicate: .bound(Term(iri: "http://example.org/value")),
                object: .bound(Term(integer: 8))
            )
            guard case .filter(
                let pattern,
                .ne(
                    .node(.bound(Term(integer: 8))),
                    .node(.bound(Term(value: "7.0", type: .datatype("http://www.w3.org/2001/XMLSchema#decimal"))))
                )) = replaced else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }

            guard case .triple(let got) = pattern else {
                XCTFail("Unexpected algebra: \(pattern.serialize())")
                return
            }
            
            XCTAssertEqual(got, tp)
        } catch let e {
            XCTFail("\(e)")
        }
    }
}
