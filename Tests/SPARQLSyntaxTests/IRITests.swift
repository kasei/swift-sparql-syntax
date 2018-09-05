import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension IRITest {
    static var allTests : [(String, (IRITest) -> () throws -> Void)] {
        return [
            ("testIRI_AbsoluteWithBase", testIRI_AbsoluteWithBase),
            ("testIRI_FragmentWithBase", testIRI_FragmentWithBase),
            ("testIRI_FullPathWithBase", testIRI_FullPathWithBase),
            ("testIRI_RelativeWithBase", testIRI_RelativeWithBase),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class IRITest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testIRI_FragmentWithBase() {
        let base = IRI(string: "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/two-nested-opt.rq")
        let rel = "#x1"
        let i = IRI(string: rel, relativeTo: base)
        XCTAssertNotNil(i)
        XCTAssertEqual(i!.absoluteString, "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/two-nested-opt.rq#x1")
    }
    
    func testIRI_RelativeWithBase() {
        let base = IRI(string: "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/two-nested-opt.rq")
        let rel = "x1"
        let i = IRI(string: rel, relativeTo: base)
        XCTAssertNotNil(i)
        XCTAssertEqual(i!.absoluteString, "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/x1")
    }
    
    func testIRI_FullPathWithBase() {
        let base = IRI(string: "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/two-nested-opt.rq")
        let rel = "/x1"
        let i = IRI(string: rel, relativeTo: base)
        XCTAssertNotNil(i)
        XCTAssertEqual(i!.absoluteString, "file:///x1")
    }
    
    func testIRI_AbsoluteWithBase() {
        let base = IRI(string: "file:///Users/greg/data/prog/git/sparql/kineo/rdf-tests/sparql11/data-r2/algebra/two-nested-opt.rq")
        let rel = "http://example/x1"
        let i = IRI(string: rel, relativeTo: base)
        XCTAssertNotNil(i)
        XCTAssertEqual(i!.absoluteString, "http://example/x1")
    }
}
