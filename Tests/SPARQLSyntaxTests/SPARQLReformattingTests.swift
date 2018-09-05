import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension SPARQLReformattingTests {
    static var allTests : [(String, (SPARQLReformattingTests) -> () throws -> Void)] {
        return [
            ("testReformat_extraContent", testReformat_extraContent),
            ("testReformat_invalidToken", testReformat_invalidToken),
            ("testReformat_plain", testReformat_plain),
            ("testReformat_pretty", testReformat_pretty),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLReformattingTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testReformat_plain() throws {
        let sparql = """
        prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        select    ?s
        where{
        ?s geo:lat ?lat ;geo:long+ ?long   ; # foo bar
            FILTER(?long < -117.0)
        FILTER(?lat >= 31.0)
          FILTER(?lat <= 33.0)
        } ORDER BY DESC(?s)
        """
        let s = SPARQLSerializer()
        let l = s.reformat(sparql)
        let expected = """
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> SELECT ?s WHERE { ?s geo:lat ?lat ; geo:long + ?long ; #  foo bar
        FILTER ( ?long < - 117.0 ) FILTER ( ?lat >= 31.0 ) FILTER ( ?lat <= 33.0 ) } ORDER BY DESC ( ?s )
        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_pretty() throws {
        let sparql = """
        prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        select    ?s
        where{
        ?s geo:lat ?lat ;geo:long+ ?long   ; # foo bar
            FILTER(?long < -117.0)
        FILTER(?lat >= 31.0)
          FILTER(?lat <= 33.0)
        } ORDER BY DESC ( ?s)
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
//        print(l)
        let expected = """
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        SELECT ?s WHERE {
            ?s geo:lat ?lat ;
                geo:long + ?long ;
                #  foo bar
            FILTER (?long < - 117.0)
            FILTER (?lat >= 31.0)
            FILTER (?lat <= 33.0)
        }
        ORDER BY DESC(?s)

        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_invalidToken() throws {
        let sparql = """
        prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        select    ?s
        where{
        ?s geo:lat lat ;geo:long+ ?long   ; # foo bar
            FILTER(?long < -117.0)
        FILTER(?lat >= 31.0)
          FILTER(?lat <= 33.0)
        } ORDER BY DESC ( ?s)
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        //        print(l)
        let expected = """
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        SELECT ?s WHERE {
            ?s geo:lat lat ;geo:long+ ?long   ; # foo bar
            FILTER(?long < -117.0)
        FILTER(?lat >= 31.0)
          FILTER(?lat <= 33.0)
        } ORDER BY DESC ( ?s)
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_extraContent() throws {
        let sparql = """
        prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        select    ?s
        where{
        ?s geo:lat ?lat ;geo:long+ ?long   ; # foo bar
            FILTER(?long < -117.0)
        FILTER(?lat >= 31.0)
          FILTER(?lat <= 33.0)
        } ORDER BY DESC ( ?s)
        foo'
          bar
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        //        print(l)
        let expected = """
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        SELECT ?s WHERE {
            ?s geo:lat ?lat ;
                geo:long + ?long ;
                #  foo bar
            FILTER (?long < - 117.0)
            FILTER (?lat >= 31.0)
            FILTER (?lat <= 33.0)
        }
        ORDER BY DESC(?s) foo'
          bar
        """
        XCTAssertEqual(l, expected)
    }
}
