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
                geo:long+ ?long ;
                #  foo bar
            FILTER(?long < - 117.0)
            FILTER(?lat >= 31.0)
            FILTER(?lat <= 33.0)
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
                geo:long+ ?long ;
                #  foo bar
            FILTER(?long < - 117.0)
            FILTER(?lat >= 31.0)
            FILTER(?lat <= 33.0)
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
            FILTER(?long < - 117.0)
            FILTER(?lat >= 31.0)
            FILTER(?lat <= 33.0)
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
        let expected = """
        DELETE {
            ?a ?b ?c
        }
        WHERE {
            {
                ?a <p> ?b ;
                    <q> ?c
            } UNION {
                SELECT ?a ?b ?c WHERE {
                    ?a ?b ?c
                }
            }
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_filterWithNewlineFromComment() throws {
        let sparql = """
        select * where {
            FILTER(#comment
            true)
        }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        let expected = """
        SELECT * WHERE {
            FILTER(# comment
                true)
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBind() throws {
        let sparql = """
        select * where { bind  (1 AS ?x) ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            BIND(1 AS ?x)
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBrackettedFilter() throws {
        let sparql = """
        select * where { filter  (true) ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            FILTER(true)
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBareFunctionFilter() throws {
        let sparql = """
        select * where { filter <http://example.org/test>(true) ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            FILTER <http://example.org/test> (true)
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBareFunctionFilterEmptyArgs() throws {
        let sparql = """
        select * where { filter <http://example.org/test>() ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            FILTER <http://example.org/test> ()
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBuiltInFilter() throws {
        let sparql = """
        select * where { filter CONTAINS(?x, ?y) ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            FILTER CONTAINS(?x , ?y)
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterBuiltInFilterEmptyArgs() throws {
        let sparql = """
        select * where { filter BNODE() ?s ?p ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            FILTER BNODE ()
            ?s ?p ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_tripleAfterNestedFilterInExists() throws {
        let sparql = """
        select * where {
            ?x ?y ?z
            filter(
                ?z && NOT EXISTS {
                    ?x <q> <r>
                    filter(true) ?x <qq> ?rr
                }
            ) ?s ?p ?o
        }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            ?x ?y ?z
            FILTER(?z && NOT EXISTS {
                    ?x <q> <r>
                    FILTER(true)
                    ?x <qq> ?rr
                }
                )
            ?s ?p ?o
        }

        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_values() throws {
        let sparql = """
        select * where { values ?x { 1 2 3 } }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT * WHERE {
            VALUES ?x
            {
                1 2 3
            }
        }

        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_prefixedname_with_underscores() throws {
        let sparql = """
        prefiX ex: <http://example.org/>
        select * where { ?s ex:foo_bar ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        PREFIX ex: <http://example.org/>
        SELECT * WHERE {
            ?s ex:foo_bar ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_propertyPath() throws {
        let sparql = """
        prefix ex: <http://example.org/>
        select * where { ?s (ex:foo+/ex:bar)* ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        PREFIX ex: <http://example.org/>
        SELECT * WHERE {
            ?s (ex:foo+/ex:bar)* ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_propertyPath2() throws {
        // Token lookahead and paren depth isn't enough state to tell that the property star
        // in this query is part of a property path (and so shouldn't have leading whitespace)
        // as opposed to part of a numeric expression.
        let sparql = """
        prefix ex: <http://example.org/>
        select * where { ?s ((ex:foo/ex:bar)*/ex:baz) ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        PREFIX ex: <http://example.org/>
        SELECT * WHERE {
            ?s ((ex:foo/ex:bar) */ex:baz) ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_prefix_base() throws {
        let sparql = """
        prefix ex1: <http://example.org/> base <http://example.org/> prefix ex2: </ns2/>
        select * from <a> where { ?s ex1:foo ?o }
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        PREFIX ex1: <http://example.org/>
        BASE <http://example.org/>
        PREFIX ex2: </ns2/>
        SELECT *
        FROM <a>
        WHERE {
            ?s ex1:foo ?o
        }
        
        """
        XCTAssertEqual(l, expected)
    }
    
    func testReformat_groupBy_orderBy() throws {
        let sparql = """
        prefix ex: <http://example.org/>
        select * where { ?s1 ex:foo ?o } group by ?s1 order by ?s1
        
        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        PREFIX ex: <http://example.org/>
        SELECT * WHERE {
            ?s1 ex:foo ?o
        }
        GROUP BY ?s1
        ORDER BY ?s1
        
        """
        XCTAssertEqual(l, expected)
    }

    func testReformat_propertyPathOperators() throws {
        let sparql = """
        SELECT DISTINCT  ?work ?date
              WHERE
                { ?work ex:related|^ex:related <http://example.org/8f59af8a-b71c-11ed-8912-01aa75ed71a1> .
                  ?work  ex:date  ?date
                }
              ORDER BY DESC(?date)

        """
        let s = SPARQLSerializer(prettyPrint: true)
        let l = s.reformat(sparql)
        
        let expected = """
        SELECT DISTINCT ?work ?date WHERE {
            ?work ex:related|^ex:related <http://example.org/8f59af8a-b71c-11ed-8912-01aa75ed71a1> .
            ?work ex:date ?date
        }
        ORDER BY DESC(?date)

        """
        XCTAssertEqual(l, expected)
    }


    // TODO: test a filter nested in another filter via an EXISTS block
}
