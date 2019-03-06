import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension SPARQLParserWindowTests {
    static var allTests : [(String, (SPARQLParserWindowTests) -> () throws -> Void)] {
        return [
            ("testRank", testRank),
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
