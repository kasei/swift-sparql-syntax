import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension SPARQLSerializationTests {
    static var allTests : [(String, (SPARQLSerializationTest) -> () throws -> Void)] {
        return [
            ("testProjectedSPARQLTokens", testProjectedSPARQLTokens),
            ("testNonProjectedSPARQLTokens", testNonProjectedSPARQLTokens),
            ("testQueryModifiedSPARQLSerialization1", testQueryModifiedSPARQLSerialization1),
            ("testQueryModifiedSPARQLSerialization2", testQueryModifiedSPARQLSerialization2),
            ("testQuerySerializedTokens_1", testQuerySerializedTokens_1),
            ("testQuerySerializedTokens_2", testQuerySerializedTokens_2),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLSerializationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testProjectedSPARQLTokens() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .project(.innerJoin(.triple(t1), .triple(t2)), ["name", "type"])
        do {
            let query = try Query(form: .select(.variables(["name", "type"])), algebra: algebra)
            let tokens = Array(try query.sparqlTokens())
            XCTAssertEqual(tokens, [
                .keyword("SELECT"),
                ._var("name"),
                ._var("type"),
                .keyword("WHERE"),
                .lbrace,
                .bnode("b"),
                .keyword("A"),
                ._var("type"),
                .dot,
                .bnode("b"),
                .iri("http://xmlns.com/foaf/0.1/name"),
                ._var("name"),
                .dot,
                .rbrace,
                ])
        } catch {
            XCTFail()
        }
    }
    
    func testNonProjectedSPARQLTokens() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .innerJoin(.triple(t1), .triple(t2))
        let tokens = Array(try algebra.sparqlTokens(depth: 0))
        XCTAssertEqual(tokens, [
            .bnode("b"),
            .keyword("A"),
            ._var("type"),
            .dot,
            .bnode("b"),
            .iri("http://xmlns.com/foaf/0.1/name"),
            ._var("name"),
            .dot,
            ])
        
        do {
            let query = try Query(form: .select(.variables(["name", "type"])), algebra: algebra)
            let qtokens = Array(try query.sparqlTokens())
            XCTAssertEqual(qtokens, [
                .keyword("SELECT"),
                ._var("name"),
                ._var("type"),
                .keyword("WHERE"),
                .lbrace,
                .bnode("b"),
                .keyword("A"),
                ._var("type"),
                .dot,
                .bnode("b"),
                .iri("http://xmlns.com/foaf/0.1/name"),
                ._var("name"),
                .dot,
                .rbrace,
                ])
        } catch {
            XCTFail()
        }
    }
    
    func testQueryModifiedSPARQLSerialization1() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let cmp = Algebra.SortComparator(ascending: false, expression: .node(.variable("name", binding: false)))
        let algebra: Algebra = .slice(.order(.innerJoin(.triple(t1), .triple(t2)), [cmp]), nil, 5)
        do {
            let query = try Query(form: .select(.variables(["name", "type"])), algebra: algebra)
            let qtokens = Array(try query.sparqlTokens())
            
            XCTAssertEqual(qtokens, [
                .keyword("SELECT"),
                ._var("name"),
                ._var("type"),
                .keyword("WHERE"),
                .lbrace,
                .bnode("b"),
                .keyword("A"),
                ._var("type"),
                .dot,
                .bnode("b"),
                .iri("http://xmlns.com/foaf/0.1/name"),
                ._var("name"),
                .dot,
                .rbrace,
                .keyword("ORDER"),
                .keyword("BY"),
                .keyword("DESC"),
                .lparen,
                ._var("name"),
                .rparen,
                .keyword("LIMIT"),
                .integer("5")
                ])
            
            let s = SPARQLSerializer()
            let sparql = s.serialize(try query.sparqlTokens())
            let expected = "SELECT ?name ?type WHERE { _:b a ?type . _:b <http://xmlns.com/foaf/0.1/name> ?name . } ORDER BY DESC ( ?name ) LIMIT 5"
            
            XCTAssertEqual(sparql, expected)
        } catch {
            XCTFail()
        }
    }
    
    func testQueryModifiedSPARQLSerialization2() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vname: Node = .variable("name", binding: true)
        let t = TriplePattern(subject: subj, predicate: name, object: vname)
        do {
            let sq = try Query(form: .select(.star), algebra: .slice(.triple(t), nil, 5))
            let cmp = Algebra.SortComparator(ascending: false, expression: .node(.variable("name", binding: false)))
            let algebra: Algebra = .order(.subquery(sq), [cmp])
            
            let query = try Query(form: .select(.star), algebra: algebra)
            
            let qtokens = Array(try query.sparqlTokens())
            // SELECT * WHERE { { SELECT * WHERE { _:b foaf:name ?name . } LIMIT 5 } } ORDER BY DESC(?name)
            XCTAssertEqual(qtokens, [
                .keyword("SELECT"),
                .star,
                .keyword("WHERE"),
                .lbrace,
                .lbrace,
                .keyword("SELECT"),
                .star,
                .keyword("WHERE"),
                .lbrace,
                .bnode("b"),
                .iri("http://xmlns.com/foaf/0.1/name"),
                ._var("name"),
                .dot,
                .rbrace,
                .keyword("LIMIT"),
                .integer("5"),
                .rbrace,
                .rbrace,
                .keyword("ORDER"),
                .keyword("BY"),
                .keyword("DESC"),
                .lparen,
                ._var("name"),
                .rparen,
                ])
        } catch {
            XCTFail()
        }
    }
    
    func testQuerySerializedTokens_1() throws {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s ex:value ?o . FILTER(?o != 7.0)\n}\n") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let tokens = Array(try q.sparqlTokens())
            let expected: [SPARQLToken] = [
                .keyword("SELECT"),
                .star,
                .keyword("WHERE"),
                .lbrace,
                ._var(".blank.b1"),
                .iri("http://example.org/value"),
                ._var("o"),
                .dot,
                .keyword("FILTER"),
                .lparen,
                ._var("o"),
                .notequals,
                .string1d("7.0"),
                .hathat,
                .iri("http://www.w3.org/2001/XMLSchema#decimal"),
                .rparen,
                .rbrace
            ]
            guard tokens.count == expected.count else { XCTFail("Got \(tokens.count), but expected \(expected.count)"); return }
            for (t, expect) in zip(tokens, expected) {
                XCTAssertEqual(t, expect)
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testQuerySerializedTokens_2() throws {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT ?o WHERE {\n_:s ex:value ?o . FILTER(?o != 7.0)\n}\n") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let tokens = Array(try q.sparqlTokens())
            let expected: [SPARQLToken] = [
                .keyword("SELECT"),
                ._var("o"),
                .keyword("WHERE"),
                .lbrace,
                ._var(".blank.b1"),
                .iri("http://example.org/value"),
                ._var("o"),
                .dot,
                .keyword("FILTER"),
                .lparen,
                ._var("o"),
                .notequals,
                .string1d("7.0"),
                .hathat,
                .iri("http://www.w3.org/2001/XMLSchema#decimal"),
                .rparen,
                .rbrace
            ]
            
            //            guard tokens.count == expected.count else { XCTFail("Got \(tokens.count), but expected \(expected.count)"); return }
            for (t, expect) in zip(tokens, expected) {
                XCTAssertEqual(t, expect)
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testQuerySerializedTokens_3() throws {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT ?o WHERE {\n_:s ex:value ?o, 7\n}\n") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let tokens = Array(try q.sparqlTokens())
            let expected: [SPARQLToken] = [
                .keyword("SELECT"),
                ._var("o"),
                .keyword("WHERE"),
                .lbrace,
                ._var(".blank.b1"),
                .iri("http://example.org/value"),
                ._var("o"),
                .dot,
                ._var(".blank.b1"),
                .iri("http://example.org/value"),
                .string1d("7"),
                .hathat,
                .iri("http://www.w3.org/2001/XMLSchema#integer"),
                .dot,
                .rbrace
            ]
            
            //            guard tokens.count == expected.count else { XCTFail("Got \(tokens.count), but expected \(expected.count)"); return }
            for (t, expect) in zip(tokens, expected) {
                XCTAssertEqual(t, expect)
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregationSerialization() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        SELECT (GROUP_CONCAT(?o; SEPARATOR="-") AS ?m) (AVG(?o) AS ?a) WHERE {
            ?s ex:value ?o
            FILTER(ISNUMERIC(?o))
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT (GROUP_CONCAT(?o ; SEPARATOR = "-") AS ?m) (AVG(?o) AS ?a) WHERE {
                ?s <http://example.org/value> ?o .
                FILTER ISNUMERIC(?o)
            }
            
            """
//            print("got: \(query)")
//            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregationSerialization_ComplexProjection() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        SELECT (SUM(?o)+AVG(?o) AS ?a) WHERE {
            ?s ex:value ?o
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
            //            print("===============")
            //            print("\(q.serialize())")
            //            print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT (SUM(?o) + AVG(?o) AS ?a) WHERE {
                ?s <http://example.org/value> ?o .
            }
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testSelectExpressionSerialization() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        SELECT (?o+2 AS ?a) WHERE {
            ?s ex:value ?o
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
            //            print("===============")
            //            print("\(q.serialize())")
            //            print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT (?o + "2"^^<http://www.w3.org/2001/XMLSchema#integer> AS ?a) WHERE {
                ?s <http://example.org/value> ?o .
            }
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testConstructWithExtensionSerialization() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        CONSTRUCT { ?s ?p ?q }
        WHERE {
            ?s ex:value ?o
            BIND(?o AS ?q)
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
            //            print("===============")
            //            print("\(q.serialize())")
            //            print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            CONSTRUCT {
                ?s ?p ?q .
            }
            WHERE {
                ?s <http://example.org/value> ?o .
                BIND (?o AS ?q)
            }
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testValuesSerialization() throws {
        let sparql = """
        PREFIX : <http://example.org/>
        SELECT * WHERE {
            VALUES (?x ?y) {
              (:uri1 1)
              (:uri2 UNDEF)
            }
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
            //            print("===============")
            //            print("\(q.serialize())")
            //            print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT * WHERE {
                VALUES (?x ?y) {
                    (<http://example.org/uri1> "1"^^<http://www.w3.org/2001/XMLSchema#integer>) (<http://example.org/uri2> UNDEF)
                }
            }
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testPrecedenceParenthsesSerialization() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        SELECT * WHERE {
            ?s ex:value/ex:value|ex:value ?o .
        }
        ORDER BY ("xyz")
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
//                        print("===============")
//                        print("\(q.serialize())")
//                        print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT * WHERE {
                ?s (<http://example.org/value> / <http://example.org/value>) | <http://example.org/value> ?o .
            }
            ORDER BY ("xyz")
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testAggregationSerialization_2() throws {
        let algebra : Algebra = .project(
            .aggregate(
                .joinIdentity,
                [],
                [
                    Algebra.AggregationMapping(aggregation: .sum(.node(.variable("o", binding: true)), false), variableName: "sum"),
                    Algebra.AggregationMapping(aggregation: .avg(.node(.variable("o", binding: true)), false), variableName: "avg")
                ]
            ),
            Set(["sum", "avg"])
        )
        do {
            let q = try Query(form: .select(.variables(["sum", "avg"])), algebra: algebra, dataset: Dataset())
            let s = SPARQLSerializer()
            let query = try s.serializePretty(q.sparqlTokens())
            let expected = """
            SELECT (SUM(?o) AS ?sum) (AVG(?o) AS ?avg) WHERE {
                {
                }
            }
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testAggregationHaving() throws {
        let sparql = """
        PREFIX ex: <http://example.org/>
        SELECT (sum(?o) AS ?sum) {
            ?s ex:value ?o
        }
        HAVING (?sum > 10)
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        let s = SPARQLSerializer()
        do {
            let q = try p.parseQuery()
//                        print("===============")
//                        print("\(q.serialize())")
//                        print("===============")
            let tokens = try q.sparqlTokens()
            let query = s.serializePretty(tokens)
            let expected = """
            SELECT (SUM(?o) AS ?sum) WHERE {
                ?s <http://example.org/value> ?o .
            }
            HAVING (?sum > "10"^^<http://www.w3.org/2001/XMLSchema#integer>)
            
            """
            //            print("got: \(query)")
            //            print("expected: \(expected)")
            XCTAssertEqual(query, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
}
