import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension PropertyPathTest {
    static var allTests : [(String, (PropertyPathTest) -> () throws -> Void)] {
        return [
            ("testComparable", testComparable),
            ("testEncodable", testEncodable),
            ("testDescription", testDescription),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class PropertyPathTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func deepPath() -> PropertyPath {
        let p1 = Term(iri: "http://example.org/p1")
        let p2 = Term(iri: "http://example.org/p2")
        let p3 = Term(iri: "http://example.org/p3")

        let pp : PropertyPath = .seq(
            .seq(
                .alt(.link(p1), .plus(.link(p2))),
                .star(.inv(.link(p3)))
            ),
            .zeroOrOne(.nps([p1, p2]))
        )
        return pp
    }
    
    func testComparable() throws {
        let pp = deepPath()
        let p1 = Term(iri: "http://example.org/abc")
        let p2 = Term(iri: "http://example.org/xyz")
        XCTAssertTrue(pp >= pp)
        XCTAssertFalse(pp < pp)

        XCTAssertLessThan(PropertyPath.link(p1), PropertyPath.link(p2))
        XCTAssertGreaterThan(PropertyPath.link(p2), PropertyPath.link(p1))

        XCTAssertLessThan(pp, PropertyPath.link(p1))
        XCTAssertLessThan(pp, PropertyPath.seq(.link(p1), .link(p1)))
        XCTAssertLessThan(pp, PropertyPath.inv(.link(p1)))
        XCTAssertLessThan(pp, PropertyPath.nps([p1]))
        XCTAssertLessThan(pp, PropertyPath.star(.link(p1)))
        XCTAssertLessThan(pp, PropertyPath.plus(.link(p1)))
        XCTAssertLessThan(pp, PropertyPath.zeroOrOne(.link(p1)))
    }
    
    func testDescription() throws {
        let pp = deepPath()
        XCTAssertEqual(pp.description, """
        seq(seq(alt(<http://example.org/p1>, oneOrMore(<http://example.org/p2>)), zeroOrMore(inv(<http://example.org/p3>))), zeroOrOne(NPS([<http://example.org/p1>, <http://example.org/p2>])))
        """)
    }
    
    func testEncodable() throws {
        let pp = deepPath()
        let je = JSONEncoder()
        let jd = JSONDecoder()
        let data = try je.encode(pp)
        let r = try jd.decode(PropertyPath.self, from: data)
        XCTAssertEqual(r, pp)
    }
}
