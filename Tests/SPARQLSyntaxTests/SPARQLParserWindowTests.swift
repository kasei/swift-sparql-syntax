import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension SPARQLParserWindowTests {
    static var allTests : [(String, (SPARQLParserWindowTests) -> () throws -> Void)] {
        return [
            ("testRank", testRank),
            ("testSerialization", testSerialization),
            ("testWindowHaving", testWindowHaving),
            ("testWindowAggregation", testWindowAggregation),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLParserWindowTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSerialization() {
        guard var p = SPARQLParser(string: "SELECT (RANK() OVER (PARTITION BY ?s ?o ORDER BY ?o RANGE BETWEEN 3 following AND current row) AS ?rank) WHERE { ?s ?p ?o }") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let s = SPARQLSerializer()
            let sparql = try s.serialize(q.sparqlTokens())
            XCTAssertEqual(sparql, "SELECT ( RANK ( ) OVER ( PARTITION BY ?s ?o ORDER BY ?o RANGE BETWEEN \"3\" ^^ <http://www.w3.org/2001/XMLSchema#integer> FOLLOWING AND CURRENT ROW ) AS ?rank ) WHERE { ?s ?p ?o . }")
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testWindowAggregation() throws {
        let sparql = """
        PREFIX : <http://example.org/>
        SELECT (AVG(?value) OVER (ORDER BY ?date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS ?movingAverage) WHERE {
            VALUES (?date ?value) {
                (1 1.0) # 1.0
                (2 2.0) # 1.5
                (3 3.0) # 2.0
                (4 2.0) # 2.33
                (5 0.0) # 2.5
                (6 0.0) # 0.66
                (7 1.0) # 0.33
            }
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let a = try p.parseAlgebra()
        XCTAssertEqual(a.inscope, ["movingAverage"])
        guard case let .project(
            .window(_, _),
            projection
            ) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
        }
        XCTAssertEqual(projection, ["movingAverage"])
    }
    
    func testWindowHaving() throws {
        let sparql = """
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        SELECT ?name ?o WHERE {
            ?s a foaf:Person ; foaf:name ?name ; foaf:schoolHomepage ?o
        }
        HAVING (RANK() OVER (PARTITION BY ?s) < 2)
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let a = try p.parseAlgebra()
        XCTAssertEqual(a.inscope, ["name", "o"])
        guard case let .project(
            .filter(
                .window(_, _),
                _
            ),
            projection
            ) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
        }
        XCTAssertEqual(projection, ["name", "o"])
    }

    func testRank() {
        guard var p = SPARQLParser(string: "SELECT (RANK() OVER (PARTITION BY ?s ?o ORDER BY ?o) AS ?rank) WHERE { ?s ?p ?o }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            let expectedMapping = Algebra.WindowFunctionMapping(
                windowApplication: WindowApplication(
                    windowFunction: .rank,
                    comparators: [
                        Algebra.SortComparator(
                            ascending: true,
                            expression: .node(.variable("o", binding: true)))
                    ],
                    partition: [.node(.variable("s", binding: true)), .node(.variable("o", binding: true))],
                    frame: WindowFrame(
                        type: .rows,
                        from: .unbound,
                        to: .unbound
                    )
                ),
                variableName: "rank"
            )
            guard case let .project(
                .window(child, m),
                projection
                ) = a else {
                    XCTFail("Unexpected algebra: \(a.serialize())")
                    return
            }
            
            XCTAssertEqual(m.count, 1)
            let gotMapping = m[0]
            XCTAssertEqual(gotMapping, expectedMapping)
            XCTAssertEqual(gotMapping.variableName, "rank")
            let app = gotMapping.windowApplication
            XCTAssertEqual(app.comparators.count, 1)
            XCTAssertEqual(app.partition.count, 2)
            XCTAssertEqual(projection, ["rank"])
            XCTAssertEqual(a.inscope, ["rank"])
            XCTAssertEqual(Algebra.window(child, m).inscope, ["s", "p", "o", "rank"])
        } catch let e {
            XCTFail("\(e)")
        }
    }
}
