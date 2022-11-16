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
    
    func testReformat_delete() throws {
        let sparql = """
        prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        delete {?s ?p ?o}
        where{
        ?s geo:lat ?lat ;geo:long ?long FILTER(?long < -117.0) FILTER(?lat >= 31.0)FILTER(?lat <= 33.0)
        }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        //        print(l)
        let expected = """
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        DELETE {
            ?s ?p ?o
        }
        WHERE {
            ?s geo:lat ?lat ;
                geo:long ?long
            FILTER (?long < - 117.0)
            FILTER (?lat >= 31.0)
            FILTER (?lat <= 33.0)
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_complexUpdate() throws {
        let sparql = """
        drop silent named;with<g1> DELETE { ?a ?b ?c } insert{ ?c?b ?a } WHERE { ?a
        ?b ?c } ;
        COPY
            default
        to <http://example.org/named>
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        //        print(l)
        let expected = """
        DROP SILENT NAMED ;
        WITH <g1>
        DELETE {
            ?a ?b ?c
        }
        INSERT {
            ?c ?b ?a
        }
        WHERE {
            ?a ?b ?c
        }
        ;
        COPY DEFAULT TO <http://example.org/named>
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_updateSubqueryProjection() throws {
        let sparql = """
        DELETE { ?a ?b ?c } WHERE {
        { ?a <p> ?b ; <q> ?c } UNION {
        SELECT ?a ?b ?c WHERE { ?a ?b ?c }}}
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        //        print(l)
        let expected = """
        DELETE {
            ?a ?b ?c
        }
        WHERE {
            {
                ?a <p> ?b ;
                    <q> ?c
            }
            UNION {
                SELECT ?a ?b ?c WHERE {
                    ?a ?b ?c
                }
            }
        }
        
        """
        XCTAssertEqual(l, expected)
    }
}
