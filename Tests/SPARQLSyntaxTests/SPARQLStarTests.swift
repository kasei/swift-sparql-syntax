import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension SPARQLStarTests {
    static var allTests : [(String, (SPARQLParserTest) -> () throws -> Void)] {
        return [
            ("testEmbeddedTripleSubject_Reification", testEmbeddedTripleSubject_Reification),
            ("testEmbeddedTripleSubject", testEmbeddedTripleSubject),
            ("testEmbeddedTripleSubjectRecursive", testEmbeddedTripleSubjectRecursive),
            ("testIncompleteEmbeddedTripleSubject", testIncompleteEmbeddedTripleSubject),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLStarTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEmbeddedTripleSubject_Reification() {
        let sparql = """
        PREFIX : <http://example.com/ns#>

        SELECT * {
            << :a :b :c >> :p1 :o1.
        }
        """
        guard let p = SPARQLParser(string: sparql) else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
//            let a = try p.parseAlgebra()
            let a = q.algebra
            guard case .bgp(let triples) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            /**
             [] a rdf:Statement ;
                rdf:subject :a ;
                rdf:predicate :b ;
                rdf:object :c ;
                :p1 :o1 .
             */
            XCTAssertEqual(triples.count, 5)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testEmbeddedTripleSubject() {
        let sparql = """
        PREFIX : <http://example.com/ns#>

        SELECT * {
            << :a :b :c >> :p1 :o1.
        }
        """
        guard let p = SPARQLStarParser(string: sparql) else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case let .innerJoin(.matchStatement(_, v), .triple(tp)) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            /**
             [] a rdf:Statement ;
                rdf:subject :a ;
                rdf:predicate :b ;
                rdf:object :c ;
                :p1 :o1 .
             */
            
            XCTAssertEqual(tp.subject, Node.variable(v, binding: true)) // The triple pattern's subject should be the variable representing the embedded statement
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testEmbeddedTripleSubjectRecursive() {
        let sparql = """
        PREFIX : <http://example.com/ns#>

        SELECT * {
            << << :a :p 1 >> :b :c >> :p1 :o1.
        }
        """
        guard let p = SPARQLStarParser(string: sparql) else { XCTFail(); return }
        do {
            let algebra = try p.parseAlgebra()
            guard case let .innerJoin(.matchStatement(embeddedPattern, v), .triple(tp)) = algebra else {
                XCTFail("Unexpected algebra: \(algebra.serialize())")
                return
            }

            let ep : Algebra.EmbeddedPattern = embeddedPattern
            guard case .embeddedTriple(.embeddedTriple, .bound, .node(.bound)) = ep else {
                XCTFail("Unexpected algebra: \(algebra.serialize())")
                return
            }
            
            XCTAssertEqual(tp.subject, Node.variable(v, binding: true)) // The triple pattern's subject should be the variable representing the embedded statement
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testIncompleteEmbeddedTripleSubject() {
        let sparql = """
        PREFIX : <http://example.com/ns#>

        SELECT * {
            << :a :b >> :p1 :o1.
        }
        """
        guard let p = SPARQLParser(string: sparql) else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra())
    }
}
