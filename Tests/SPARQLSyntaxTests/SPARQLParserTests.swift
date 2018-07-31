import XCTest
import Foundation
import SPARQLSyntax

#if os(Linux)
extension SPARQLParserTests {
    static var allTests : [(String, (SPARQLParserTest) -> () throws -> Void)] {
        return [
            ("testParser", testParser),
            ("testLexer", testLexer),
            ("testLexerPositionedTokens", testLexerPositionedTokens),
            ("testLexerSingleQuotedStrings", testLexerSingleQuotedStrings),
            ("testLexerDoubleQuotedStrings", testLexerDoubleQuotedStrings),
            ("testLexerBalancing", testLexerBalancing),
            ("testLexerBalancedDelimiter", testLexerBalancedDelimiter),
            ("testProjectExpression", testProjectExpression),
            ("testSubSelect", testSubSelect),
            ("testBuiltinFunctionCallExpression", testBuiltinFunctionCallExpression),
            ("testFunctionCallExpression", testFunctionCallExpression),
            ("testAggregation1", testAggregation1),
            ("testAggregation2", testAggregation2),
            ("testAggregationGroupBy", testAggregationGroupBy),
            ("testAggregationHaving", testAggregationHaving),
            ("testInlineData1", testInlineData1),
            ("testInlineData2", testInlineData2),
            ("testFilterNotIn", testFilterNotIn),
            ("testList", testList),
            ("testConstruct", testConstruct),
            ("testDescribe", testDescribe),
            ("testNumericLiteral", testNumericLiteral),
            ("testBind", testBind),
            ("testConstructCollection1", testConstructCollection1),
            ("testConstructCollection2", testConstructCollection2),
            ("testConstructBlank", testConstructBlank),
            ("testI18N", testI18N),
            ("testIRIResolution", testIRIResolution),
            ("testAggregationProjection1", testAggregationProjection1),
            ("testAggregationProjection2", testAggregationProjection2),
            ("testSubSelectAggregationProjection", testSubSelectAggregationProjection),
            ("testSubSelectAggregationAcceptableProjection", testSubSelectAggregationAcceptableProjection),
            ("testBadReuseOfBlankNodeIdentifier", testBadReuseOfBlankNodeIdentifier),
            ("testAcceptableReuseOfBlankNodeIdentifier", testAcceptableReuseOfBlankNodeIdentifier),
            ("testi18n", testi18n),
            ("testService", testService),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class SPARQLParserTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testParser() {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s ex:value ?o . FILTER(?o != 7.0)\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .filter(let pattern, .ne(.node(.variable("o", binding: true)), .node(.bound(Term(value: "7.0", type: .datatype(.decimal)))))) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            guard case .triple(_) = pattern else {
                XCTFail("Unexpected algebra: \(pattern.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testLexer() {
        guard let data = "HR:resumé ?resume [ [] { - @en-US 'foo' \"bar\" PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s ex:value ?o . FILTER(?o != 7.0)\n}\n".data(using: .utf8) else { XCTFail(); return }
        //        guard let data = "[ [] { - @en-US".data(using: .utf8) else { XCTFail(); return }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        XCTAssertEqual(lexer.next()!, .prefixname("HR", "resumé"), "expected token")
        XCTAssertEqual(lexer.next()!, ._var("resume"), "expected token")
        XCTAssertEqual(lexer.next()!, .lbracket, "expected token")
        XCTAssertEqual(lexer.next()!, .anon, "expected token")
        XCTAssertEqual(lexer.next()!, .lbrace, "expected token")
        XCTAssertEqual(lexer.next()!, .minus, "expected token")
        XCTAssertEqual(lexer.next()!, .lang("en-us"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1s("foo"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1d("bar"), "expected token")
        
        XCTAssertEqual(lexer.next()!, .keyword("PREFIX"), "expected token")
        XCTAssertEqual(lexer.next()!, .prefixname("ex", ""), "expected token")
        XCTAssertEqual(lexer.next()!, .iri("http://example.org/"), "expected token")
        
        XCTAssertEqual(lexer.next()!, .keyword("SELECT"), "expected token")
        XCTAssertEqual(lexer.next()!, .star, "expected token")
        XCTAssertEqual(lexer.next()!, .keyword("WHERE"), "expected token")
        XCTAssertEqual(lexer.next()!, .lbrace, "expected token")
        XCTAssertEqual(lexer.next()!, .bnode("s"), "expected token")
        XCTAssertEqual(lexer.next()!, .prefixname("ex", "value"), "expected token")
        XCTAssertEqual(lexer.next()!, ._var("o"), "expected token")
        XCTAssertEqual(lexer.next()!, .dot, "expected token")
        XCTAssertEqual(lexer.next()!, .keyword("FILTER"), "expected token")
        XCTAssertEqual(lexer.next()!, .lparen, "expected token")
        XCTAssertEqual(lexer.next()!, ._var("o"), "expected token")
        XCTAssertEqual(lexer.next()!, .notequals, "expected token")
        XCTAssertEqual(lexer.next()!, .decimal("7.0"), "expected token")
        XCTAssertEqual(lexer.next()!, .rparen, "expected token")
        XCTAssertEqual(lexer.next()!, .rbrace, "expected token")
        XCTAssertNil(lexer.next())
    }
    
    func testLexerPositionedTokens() {
        guard let sparql = "SELECT * WHERE { ?s <p> 'o' }".data(using: .utf8) else { XCTFail(); return }
        let stream = InputStream(data: sparql)
        stream.open()
        let lexer = SPARQLLexer(source: stream, includeComments: false)
        let pt = lexer.nextPositionedToken()!
        let loc = pt.startCharacter
        let len = pt.endCharacter - pt.startCharacter
        XCTAssertEqual(loc, 0)
        XCTAssertEqual(len, 6)
        
        let tokens: UnfoldSequence<PositionedToken, Int> = sequence(state: 0) { (_) in return lexer.nextPositionedToken() }
        let expected = [
            (7,1),
            (9,5),
            (15,1),
            (17,2),
            (20,3),
            (24,3),
            (28,1),
            ]
        
        let positions = tokens.map { (Int($0.startCharacter), Int($0.endCharacter-$0.startCharacter)) }
        let comparisions = zip(positions, expected)
        for (got, expected) in comparisions {
//            print("got: \(got); expected: \(expected)")
            XCTAssertEqual(got.0, expected.0)
            XCTAssertEqual(got.1, expected.1)
        }
    }
    
    func testLexerSingleQuotedStrings() {
        guard let data = "'foo' 'foo\\nbar' '\\u706B' '\\U0000661F' '''baz''' '''' ''' ''''''''".data(using: .utf8) else { XCTFail(); return }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        
        XCTAssertEqual(lexer.next()!, .string1s("foo"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1s("foo\nbar"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1s("火"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1s("星"), "expected token")
        XCTAssertEqual(lexer.next()!, .string3s("baz"), "expected token")
        XCTAssertEqual(lexer.next()!, .string3s("' "), "expected token")
        XCTAssertEqual(lexer.next()!, .string3s("''"), "expected token")
    }
    
    func testLexerDoubleQuotedStrings() {
        guard let data = "\"foo\" \"foo\\nbar\" \"\\u706B\" \"\\U0000661F\" \"\"\"baz\"\"\" \"\"\"\" \"\"\" \"\"\"\"\"\"\"\"".data(using: .utf8) else { XCTFail(); return }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        
        XCTAssertEqual(lexer.next()!, .string1d("foo"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1d("foo\nbar"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1d("火"), "expected token")
        XCTAssertEqual(lexer.next()!, .string1d("星"), "expected token")
        XCTAssertEqual(lexer.next()!, .string3d("baz"), "expected token")
        XCTAssertEqual(lexer.next()!, .string3d("\" "), "expected token")
        XCTAssertEqual(lexer.next()!, .string3d("\"\""), "expected token")
    }
    
    func testLexerPropertyPath() {
        guard let data = "prefix : <http://example/> select * where { :a (:p/:p)? ?t }".data(using: .utf8) else { XCTFail(); return }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        var tokens = [SPARQLToken]()
        while let t = lexer.next() {
            tokens.append(t)
        }
        let expected : [SPARQLToken] = [
            .keyword("PREFIX"),
            .prefixname("", ""),
            .iri("http://example/"),
            .keyword("SELECT"),
            .star,
            .keyword("WHERE"),
            .lbrace,
            .prefixname("", "a"),
            .lparen,
            .prefixname("", "p"),
            .slash,
            .prefixname("", "p"),
            .rparen,
            .question,
            ._var("t"),
            .rbrace
        ]
        XCTAssertEqual(tokens, expected)
    }
    
    func testProjectExpression() {
        guard var p = SPARQLParser(string: "SELECT (?x+1 AS ?y) ?x WHERE {\n_:s <p> ?x .\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(let algebra, let variables) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(variables, ["y", "x"])
            guard case .extend(_, _, "y") = algebra else { XCTFail(); return }
            
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testSubSelect() {
        guard var p = SPARQLParser(string: "SELECT ?x WHERE {\n{ SELECT ?x ?y { ?x ?y ?z } }}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(let algebra, let variables) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(variables, ["x"])
            
            guard case .subquery(let q) = algebra else {
                XCTFail("Unexpected algebra: \(algebra.serialize())")
                return
            }
            
            guard case .project(_, let subvariables) = q.algebra else {
                XCTFail("Unexpected algebra: \(algebra.serialize())")
                return
            }
            
            XCTAssertEqual(subvariables, ["x", "y"])
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testBuiltinFunctionCallExpression() {
        guard var p = SPARQLParser(string: "SELECT * WHERE {\n_:s <p> ?x . FILTER ISNUMERIC(?x)\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .filter(_, let expr) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            let expected: Expression = .isnumeric(.node(.variable("x", binding: true)))
            XCTAssertEqual(expr, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testFunctionCallExpression() {
        guard var p = SPARQLParser(string: "PREFIX ex: <http://example.org/> SELECT * WHERE {\n_:s <p> ?x . FILTER ex:function(?x)\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .filter(_, let expr) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            let expected: Expression = .call("http://example.org/function", [.node(.variable("x", binding: true))])
            XCTAssertEqual(expr, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregation1() {
        guard var p = SPARQLParser(string: "SELECT ?x (SUM(?y) AS ?z) WHERE {\n?x <p> ?y\n}\nGROUP BY ?x") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(let agg, let projection) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            let aggMap = Algebra.AggregationMapping(aggregation: .sum(.node(.variable("y", binding: true)), false), variableName: "z")
            guard case .aggregate(_, let groups, [aggMap]) = agg else {
                XCTFail("Unexpected algebra: \(agg.serialize())")
                return
            }
            
            XCTAssertEqual(projection, ["x", "z"])
            let expected: [Expression] = [.node(.variable("x", binding: true))]
            XCTAssertEqual(groups, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregation2() {
        guard var p = SPARQLParser(string: "SELECT ?x (SUM(?y) AS ?sum) (AVG(?y) AS ?avg) WHERE {\n?x <p> ?y\n}\nGROUP BY ?x") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(let agg, let projection) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            let aggMap1 = Algebra.AggregationMapping(aggregation: .sum(.node(.variable("y", binding: true)), false), variableName: "sum")
            let aggMap2 = Algebra.AggregationMapping(aggregation: .avg(.node(.variable("y", binding: true)), false), variableName: "avg")

            guard case .aggregate(_, let groups, [aggMap1, aggMap2]) = agg else {
                XCTFail("Unexpected algebra: \(agg.serialize())")
                return
            }
            
            XCTAssertEqual(projection, ["x", "sum", "avg"])
            let expected: [Expression] = [.node(.variable("x", binding: true))]
            XCTAssertEqual(groups, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregationGroupBy() {
        guard var p = SPARQLParser(string: "SELECT ?x WHERE {\n_:s <p> ?x\n}\nGROUP BY ?x") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(.aggregate(_, let groups, let aggs), let projection) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(aggs.count, 0)
            XCTAssertEqual(projection, ["x"])
            let expected: [Expression] = [.node(.variable("x", binding: true))]
            XCTAssertEqual(groups, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregationHaving() {
        guard var p = SPARQLParser(string: "SELECT ?x WHERE {\n_:s <p> ?x\n}\nGROUP BY ?x HAVING (?x > 2)") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(.filter(.aggregate(_, let groups, let aggs), .gt(.node(.variable("x", binding: true)), .node(.bound(Term(value: "2", type: .datatype(.integer)))))), let projection) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(aggs.count, 0)
            XCTAssertEqual(projection, ["x"])
            let expected: [Expression] = [.node(.variable("x", binding: true))]
            XCTAssertEqual(groups, expected)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testInlineData1() {
        guard var p = SPARQLParser(string: "SELECT ?x WHERE {\nVALUES ?x {7 2 3}\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .project(let table, _) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            guard case .table(let nodes, let seq) = table else {
                XCTFail("Unexpected algebra: \(table.serialize())")
                return
            }
            
            let expectedInScope: [Node] = [.variable("x", binding: true)]
            XCTAssertEqual(nodes, expectedInScope)
            
            let terms = Array(seq)
            XCTAssertEqual(terms.count, 3)
            let term = terms[0]
            let expectedTerm = [Term(integer: 7)]
            XCTAssertEqual(term, expectedTerm)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testInlineData2() {
        guard var p = SPARQLParser(string: "SELECT * WHERE {\n\n}\nVALUES (?x ?y) { (UNDEF 7) (2 UNDEF) }\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .innerJoin(.joinIdentity, let table) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            guard case .table(let nodes, let rows) = table else {
                XCTFail("Unexpected algebra: \(table.serialize())")
                return
            }
            
            let expectedInScope: [Node] = [.variable("x", binding: true), .variable("y", binding: true)]
            XCTAssertEqual(nodes, expectedInScope)
            
            let pairs = Array(rows)
            XCTAssertEqual(pairs.count, 2)
            let pair = pairs[0]
            let expectedTerms = [nil, Term(integer: 7)]
            XCTAssertEqual(pair, expectedTerms)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testFilterNotIn() {
        guard var p = SPARQLParser(string: "SELECT * WHERE {\n?x ?y ?z . FILTER(?z NOT IN (1,2,3))\n}\n") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .filter(_, let expr) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            guard case .not(.valuein(_, _)) = expr else {
                XCTFail("Unexpected expression: \(expr.description)")
                return
            }
            
            XCTAssertEqual(expr.description, "?z NOT IN (1,2,3)")
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testList() {
        guard var p = SPARQLParser(string: "SELECT * WHERE { ( () ) }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .bgp(let triples) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(triples.count, 2)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testPropertyPath_zeroOrOne() {
        guard var p = SPARQLParser(string: "prefix : <http://example/> select * where { :a (:p/:p)? ?t }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .path(_, .zeroOrOne(_), _) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testConstruct() {
        guard var p = SPARQLParser(string: "CONSTRUCT { ?s <p1> <o> . ?s <p2> ?o } WHERE {?s ?p ?o}") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let a = q.algebra
            guard case .construct(let ctriples) = q.form else {
                XCTFail("Unexpected query form: \(q.form)")
                return
            }
            guard case .distinct(.triple(_)) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(ctriples.count, 2)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testDescribe() {
        guard var p = SPARQLParser(string: "DESCRIBE <u>") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let a = q.algebra
            guard case .describe(let nodes) = q.form else {
                XCTFail("Unexpected query form: \(q.form)")
                return
            }
            guard case .distinct(.joinIdentity) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(nodes.count, 1)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testNumericLiteral() {
        guard var p = SPARQLParser(string: "SELECT * WHERE { <a><b>-1 }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .triple(_) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testBind() {
        guard var p = SPARQLParser(string: "PREFIX : <http://www.example.org> SELECT * WHERE { :s :p ?o . BIND((1+?o) AS ?o1) :s :q ?o1 }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .innerJoin(.extend(_, _, _), _) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testConstructCollection1() {
        guard var p = SPARQLParser(string: "PREFIX : <http://www.example.org> CONSTRUCT { ?s :p (1 2) } WHERE { ?s ?p ?o }") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let a = q.algebra
            guard case .construct(let template) = q.form else {
                XCTFail("Unexpected query form: \(q.form)")
                return
            }
            guard case .distinct(.triple(_)) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(template.count, 5)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testConstructCollection2() {
        guard var p = SPARQLParser(string: "PREFIX : <http://www.example.org> CONSTRUCT { (1 2) :p ?o } WHERE { ?s ?p ?o }") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let a = q.algebra
            guard case .construct(let template) = q.form else {
                XCTFail("Unexpected query form: \(q.form)")
                return
            }
            guard case .distinct(.triple(_)) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(template.count, 5)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testConstructBlank() {
        guard var p = SPARQLParser(string: "PREFIX : <http://www.example.org> CONSTRUCT { [ :p ?o ] } WHERE { ?s ?p ?o }") else { XCTFail(); return }
        do {
            let q = try p.parseQuery()
            let a = q.algebra
            guard case .construct(let template) = q.form else {
                XCTFail("Unexpected query form: \(q.form)")
                return
            }
            guard case .distinct(.triple(_)) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(template.count, 1)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testI18N() {
        guard var p = SPARQLParser(string: "PREFIX foaf: <http://xmlns.com/foaf/0.1/> PREFIX 食: <http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#> SELECT ?name ?food WHERE { [ foaf:name ?name ; 食:食べる ?food ] . }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case let .project(.bgp(triples), variables) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            let ta = triples[0]
            let tb = triples[1]
            
            XCTAssertEqual(ta.subject, tb.subject)
            XCTAssertEqual(ta.predicate, .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri)))
            XCTAssertEqual(ta.object, .variable("name", binding: true))
            
            XCTAssertEqual(tb.predicate, .bound(Term(value: "http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる", type: .iri)))
            XCTAssertEqual(tb.object, .variable("food", binding: true))
            
            XCTAssertEqual(variables, ["name", "food"])
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testIRIResolution() {
        guard var p = SPARQLParser(string: "BASE <http://example.org/foo/> SELECT * WHERE { ?s <p> <../bar> }") else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case .triple(let triple) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(triple.subject, .variable("s", binding: true))
            XCTAssertEqual(triple.predicate, .bound(Term(value: "http://example.org/foo/p", type: .iri)))
            XCTAssertEqual(triple.object, .bound(Term(value: "http://example.org/bar", type: .iri)))
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testAggregationProjection1() {
        guard var p = SPARQLParser(string: "SELECT * WHERE { ?s <p> 'o' } GROUP BY ?s") else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Aggregation queries cannot use a `SELECT *`"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testAggregationProjection2() {
        guard var p = SPARQLParser(string: "SELECT ?s (MIN(?p) AS ?minpred) ?o WHERE { ?s ?p ?o } GROUP BY ?s") else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Cannot project non-grouped variable(s)"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testSubSelectAggregationProjection() {
        guard var p = SPARQLParser(string: "SELECT ?s WHERE { { SELECT * WHERE { ?s <p> 'o' } GROUP BY ?s } }") else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Aggregation subqueries cannot use a `SELECT *`"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testSubSelectAggregationAcceptableProjection() {
        guard var p = SPARQLParser(string: "SELECT * WHERE { { SELECT ?s (MAX(?o) AS ?mx) WHERE { ?s <p> ?o } GROUP BY ?s } }") else { XCTFail(); return }
        XCTAssertNoThrow(try p.parseAlgebra(), "Can project * when subquery properly projects aggregated variables")
    }
    
    func testBadReuseOfBlankNodeIdentifier1() {
        guard var p = SPARQLParser(string: "SELECT * WHERE { { _:a ?p ?o . FILTER(ISIRI(?p)) _:a ?p 2 } OPTIONAL { _:a ?y ?z ; <q> 'qq' } }") else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Blank node label"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testBadReuseOfBlankNodeIdentifier2() {
        let sparql = """
        # $Id: syn-blabel-cross-graph-bad.rq,v 1.2 2007/04/18 23:11:57 eric Exp $
        # BNode label used across a GRAPH.
        PREFIX : <http://xmlns.com/foaf/0.1/>

        ASK { _:who :homepage ?homepage
              GRAPH ?g { ?someone :made ?homepage }
              _:who :schoolHomepage ?schoolPage }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Blank node label"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testBadReuseOfBlankNodeIdentifier3() {
        let sparql = """
        # $Id: syn-blabel-cross-optional-bad.rq,v 1.5 2007/09/04 15:04:22 eric Exp $
        # BNode label used across an OPTIONAL.
        # This isn't necessarily a *syntax* test, but references to bnode labels
        # may not span basic graph patterns.
        PREFIX foaf:     <http://xmlns.com/foaf/0.1/>

        ASK { _:who foaf:homepage ?homepage
              OPTIONAL { ?someone foaf:made ?homepage }
              _:who foaf:schoolHomepage ?schoolPage }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        XCTAssertThrowsError(try p.parseAlgebra()) { (e) -> Void in
            if case .some(.parsingError(let m)) = e as? SPARQLSyntaxError {
                XCTAssertTrue(m.contains("Blank node label"))
            } else {
                XCTFail()
            }
        }
    }
    
    func testAcceptableReuseOfBlankNodeIdentifier() {
        // reuse of bnode labels should be acceptable when in adjacent BGPs and property paths
        // https://www.w3.org/2013/sparql-errata#errata-query-17
        guard var p = SPARQLParser(string: "SELECT * WHERE { _:a ?p ?o ; <q>* 1 }") else { XCTFail(); return }
        XCTAssertNoThrow(try p.parseAlgebra(), "Can use blank node labels in adjacet BGPs and property paths")
    }
    
    func testi18n() {
        let sparql = """
        # $Id: kanji-01.rq,v 1.3 2005/11/06 08:27:50 eric Exp $
        # test kanji QNames
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX 食: <http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#>
        SELECT ?name ?food WHERE {
          [ foaf:name ?name ;
            食:食べる ?food ] . }
        """
        
        let base = "https://raw.githubusercontent.com/w3c/rdf-tests/gh-pages/sparql11/data-r2/i18n/kanji-01.rq"
        guard var p = SPARQLParser(string: sparql, base: base) else { XCTFail(); return }
        
        do {
            let a = try p.parseAlgebra()
            guard case .project(.bgp(let tps), _) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }

            XCTAssertEqual(tps.count, 2)
            let t = tps.filter { $0.object == Node.variable("food", binding: true) }.first
            XCTAssertNotNil(t)
            guard case .bound(let pred) = t!.predicate else { fatalError() }
            XCTAssertEqual(pred.value, "http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/kanji.ttl#食べる")
        } catch let e {
            XCTFail("I18N error: \(e)")
        }
    }

    func testi18nNormalization() {
        _testi18nNormalization(base: nil)
        _testi18nNormalization(base: "https://raw.githubusercontent.com/w3c/rdf-tests/gh-pages/sparql11/data-r2/i18n/")
    }
    
    func _testi18nNormalization(base: String?) {
        let sparql = """
        # Figure out what happens with normalization form C.
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX HR: <http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/normalization.ttl#>
        SELECT ?name
         WHERE { [ foaf:name ?name;
                   HR:resumé ?resume ] . }
        """
        guard var p = SPARQLParser(string: sparql, base: base) else { XCTFail(); return }
        
        do {
            let a = try p.parseAlgebra()
            guard case .project(.bgp(let tps), _) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            
            XCTAssertEqual(tps.count, 2)
            let t = tps.filter { $0.object == Node.variable("resume", binding: true) }.first
            XCTAssertNotNil(t)
            guard case .bound(let pred) = t!.predicate else { fatalError() }
            XCTAssertEqual(pred.value, "http://www.w3.org/2001/sw/DataAccess/tests/data/i18n/normalization.ttl#resumé")
        } catch let e {
            XCTFail("I18N error: \(e)")
        }
    }
    
    func testService() throws {
        let sparql = """
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        SELECT * WHERE {
            SERVICE SILENT <http://dbpedia.org/sparql> {
                ?s a foaf:Person .
            }
        }
        """
        guard var p = SPARQLParser(string: sparql) else { XCTFail(); return }
        do {
            let a = try p.parseAlgebra()
            guard case let .service(endpoint, algebra, silent) = a else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            let expected = URL(string: "http://dbpedia.org/sparql")!
            XCTAssertEqual(endpoint, expected)
            guard case .triple(_) = algebra else {
                XCTFail("Unexpected algebra: \(a.serialize())")
                return
            }
            XCTAssertEqual(silent, true)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testLexerBalancing() throws {
        let tests = [
            "(": ("(?long < - 117.0)", 0),
            "名": ("{ ?s ex:名前 ?name . }", 0),
            "33": ("(?lat <= 33.0)", 0),
            "20": ("", 0),
            "30": ("(?lat >= (30.0 + 1))", 1),
            "geo:long": ("{\n    ?s geo:lat ?lat ;\n        geo:long ?long ;\n    OPTIONAL { ?s ex:名前 ?name . }\n    FILTER(?long < - 117.0)\n    FILTER(?long > - 120.0)\n    FILTER(?lat >= (30.0 + 1))\n    FILTER(?lat <= 33.0)\n}", 0),
        ]
        
        let sparql = """
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        PREFIX ex: <http://example.org/>
        SELECT ?s ?name WHERE {
            ?s geo:lat ?lat ;
                geo:long ?long ;
            OPTIONAL { ?s ex:名前 ?name . }
            FILTER(?long < - 117.0)
            FILTER(?long > - 120.0)
            FILTER(?lat >= (30.0 + 1))
            FILTER(?lat <= 33.0)
        }
        LIMIT 20
        """
        
        for (patternString, data) in tests {
            let balancedString = data.0
            let depth = data.1
            let range = sparql.range(of: patternString)!
            let balancedRange = try SPARQLLexer.balancedRange(containing: range, in: sparql, level: depth)
            let balanced = String(sparql[balancedRange])
            XCTAssertEqual(balanced, balancedString)
            print(balanced)
        }
    }

    func testLexerBalancedDelimiter() throws {
        let tests : [(leftOffset: Int?, rightOffset: Int, leftString: String, rightString: String)] = [
            (245, 261, "(", ")"),
            (310, 319, "(", ")"),
            (152, 347, "{", "}"),
            (nil, 222, "", "名") // not a delimiter
        ]
        let sparql = """
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
        PREFIX ex: <http://example.org/>
        SELECT ?s ?name WHERE {
            ?s geo:lat ?lat ;
                geo:long ?long ;
            OPTIONAL { ?s ex:名前 ?name . }
            FILTER(?long < - 117.0)
            FILTER(?long > - 120.0)
            FILTER(?lat >= (30.0 + 1))
            FILTER(?lat <= 33.0)
        }
        LIMIT 20
        """
        
        for data in tests {
            let firstRight = sparql.index(sparql.startIndex, offsetBy: data.rightOffset)
            let range = firstRight..<sparql.index(after: firstRight)
            XCTAssertEqual(String(sparql[firstRight]), data.rightString)
            XCTAssertEqual(String(sparql[range]), data.rightString)
            let matching = try SPARQLLexer.matchingDelimiterRange(for: range, in: sparql)
            
            if let leftOffset = data.leftOffset {
                XCTAssertNotNil(matching)
                let opening = String(sparql[matching!])
                XCTAssertEqual(opening, data.leftString)
                let firstLeft = sparql.index(sparql.startIndex, offsetBy: leftOffset)
                XCTAssert(String(sparql[firstLeft]) == String(data.leftString))
                XCTAssertEqual(matching!, firstLeft..<sparql.index(after:firstLeft))
            } else {
                XCTAssertNil(matching)
            }
        }
    }
}
