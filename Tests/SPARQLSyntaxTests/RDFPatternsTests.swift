import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension RDFPatternsTest {
    static var allTests : [(String, (RDFPatternsTest) -> () throws -> Void)] {
        return [
            ("test_predicateSet", test_predicateSet),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class RDFPatternsTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func test_predicateSet() {
        let ex = TermNamespace(namespace: Namespace(value: "http://example.org/"))
        let nex = NodeNamespace(namespace: Namespace(value: "http://example.org/"))

        let rdf = TermNamespace(namespace: Namespace.rdf)
        let nrdf = NodeNamespace(namespace: Namespace.rdf)

        let patterns : [TriplePattern] = [
            TriplePattern(subject: nex.s3b, predicate: nrdf.type, object: nex.Type1),
            TriplePattern(subject: nex.s3b, predicate: nex.p2, object: .bound(Term.trueValue)),
            TriplePattern(subject: nex.s3b, predicate: nex.p2, object: .bound(Term.falseValue)),
            TriplePattern(subject: nex.s3b, predicate: nex.p3, object: .bound(Term.trueValue)),
        ]
        
        let bgp = BGP(patterns)
        let preds = bgp.predicateSet
        XCTAssertEqual(preds, Set([rdf.type, ex.p2, ex.p3]))
    }
}
