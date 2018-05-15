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
    
    func testMultipleRewrite() {
        // the use of rewrite() here first replaces the variable name in .extend(_, _, name) with "XXX",
        // and then rewrites the extend's child algebra (a .triple) with a .bgp containing a triple
        // with a different object value
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s ex:value 7 . BIND(1 AS ?s)\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            let replaced = try a.rewrite({ (a) -> RewriteStatus<Algebra> in
                switch a {
                case let .extend(a, e, _):
                    print(">>> \(a)")
                    return .rewriteChildren(.extend(a, e, "XXX"))
                case .triple(let tp):
                    let p = TriplePattern(subject: tp.subject, predicate: tp.predicate, object: .bound(Term(integer: 8)))
                    return .rewriteChildren(.bgp([p]))
                default:
                    return .rewriteChildren(a)
                }
            })
            let tp = TriplePattern(
                subject: .variable(".blank.b1", binding: true),
                predicate: .bound(Term(iri: "http://example.org/value")),
                object: .bound(Term(integer: 8))
            )
            guard case .extend(.bgp(let got), _, "XXX") = replaced else {
                XCTFail("Unexpected algebra: \(replaced.serialize())")
                return
            }
            
            XCTAssertEqual(got[0], tp)
        } catch let e {
            XCTFail("\(e)")
        }
    }
}
