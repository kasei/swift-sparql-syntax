import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension AlgebraTest {
    static var allTests : [(String, (AlgebraTest) -> () throws -> Void)] {
        return [
            ("testExpressionReplacement", testExpressionReplacement),
            ("testFilterExpressionReplacement", testFilterExpressionReplacement),
            ("testJoinIdentityReplacement", testJoinIdentityReplacement),
            ("testNodeBinding", testNodeBinding),
            ("testNodeBindingWithProjection", testNodeBindingWithProjection),
            ("testReplacement1", testReplacement1),
            ("testReplacement2", testReplacement2),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class AlgebraTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testReplacement1() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let pred: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let obj: Node = .variable("o", binding: true)
        let t = TriplePattern(subject: subj, predicate: pred, object: obj)
        let algebra: Algebra = .bgp([t])
        
        do {
            let rewrite = try algebra.replace { (algebra: Algebra) in
                switch algebra {
                case .bgp(_):
                    return .joinIdentity
                default:
                    return nil
                }
            }
            
            guard case .joinIdentity = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch {
            XCTFail()
        }
    }
    
    func testReplacement2() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .innerJoin(.bgp([t1]), .triple(t2))
        
        do {
            let rewrite = try algebra.replace { (algebra: Algebra) in
                switch algebra {
                case .bgp(_):
                    return .joinIdentity
                default:
                    return nil
                }
            }
            
            guard case .innerJoin(.joinIdentity, .triple(_)) = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch {
            XCTFail()
        }
    }
    
    func testJoinIdentityReplacement() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vname: Node = .variable("name", binding: true)
        let t = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .innerJoin(.joinIdentity, .triple(t))
        
        do {
            let rewrite = try algebra.replace { (algebra: Algebra) in
                switch algebra {
                case .innerJoin(.joinIdentity, let a), .innerJoin(let a, .joinIdentity):
                    return a
                default:
                    return nil
                }
            }
            
            guard case .triple(_) = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch {
            XCTFail()
        }
    }
    
    func testFilterExpressionReplacement() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let greg: Node = .bound(Term(value: "Gregory", type: .language("en")))
        let vname: Node = .variable("name", binding: true)
        let expr: Expression = .eq(.node(vname), .node(greg))
        
        let t = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .filter(.triple(t), expr)
        
        do {
            let rewrite = try algebra.replace { (expr: Expression) in
                switch expr {
                case .eq(let a, let b):
                    return .ne(a, b)
                default:
                    return nil
                }
            }
            
            guard case .filter(.triple(_), .ne(_, _)) = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            
            XCTAssert(true)
        } catch {
            XCTFail()
        }
    }
    
    func testExpressionReplacement() {
        let greg: Node = .bound(Term(value: "Gregory", type: .language("en")))
        let vname: Node = .variable("name", binding: true)
        let expr: Expression = .eq(.node(vname), .node(greg))
        
        do {
            let rewrite = try expr.replace { (expr: Expression) in
                switch expr {
                case .eq(let a, let b):
                    return .ne(a, b)
                default:
                    return nil
                }
            }
            
            XCTAssertEqual(expr.description, "(?name == \"Gregory\"@en)")
            XCTAssertEqual(rewrite.description, "(?name != \"Gregory\"@en)")
        } catch {
            XCTFail()
        }
    }
    
    func testNodeBinding() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .project(.innerJoin(.triple(t1), .triple(t2)), ["name", "type"])
        
        do {
            let rewrite = try algebra.bind("type", to: .bound(Term(value: "http://xmlns.com/foaf/0.1/Person", type: .iri)))
            guard case .project(.innerJoin(_, _), let projection) = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            XCTAssertEqual(projection, ["name"])
        } catch {
            XCTFail()
        }
    }
    
    func testNodeBindingWithProjection() {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .project(.innerJoin(.triple(t1), .triple(t2)), ["name", "type"])
        
        do {
            let person: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/Person", type: .iri))
            let rewrite = try algebra.bind("type", to: person, preservingProjection: true)
            guard case .project(.extend(.innerJoin(_, _), .node(person), "type"), let projection) = rewrite else {
                XCTFail("Unexpected rewritten algebra: \(rewrite.serialize())")
                return
            }
            XCTAssertEqual(projection, ["name", "type"])
        } catch {
            XCTFail()
        }
    }
    
    func testEncodable() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let algebra: Algebra = .project(.innerJoin(.triple(t1), .triple(t2)), ["name", "type"])
        let je = JSONEncoder()
        let jd = JSONDecoder()
        let data = try je.encode(algebra)
        let r = try jd.decode(Algebra.self, from: data)
        print("decoded: \(r.serialize())")
        XCTAssertEqual(r, algebra)
    }
    
    func testNecessarilyBound() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        
        let algebra1 = Algebra.project(.innerJoin(.triple(t1), .triple(t2)), ["name", "type"])
        XCTAssertEqual(algebra1.inscope, Set(["type", "name"]))
        XCTAssertEqual(algebra1.necessarilyBound, Set(["type", "name"]))
        
        let algebra2 = Algebra.leftOuterJoin(.triple(t1), .triple(t2), .node(Node(term: Term.trueValue)))
        XCTAssertEqual(algebra2.inscope, Set(["type", "name"]))
        XCTAssertEqual(algebra2.necessarilyBound, Set(["type"]))
        
        let algebra3 = Algebra.union(.triple(t1), .triple(t2))
        XCTAssertEqual(algebra3.inscope, Set(["type", "name"]))
        XCTAssertEqual(algebra3.necessarilyBound, Set([]))
    }
    
    func testWalk() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        let name: Node = .bound(Term(value: "http://xmlns.com/foaf/0.1/name", type: .iri))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        
        var algebra = Algebra.leftOuterJoin(.bgp([t1]), .triple(t2), .node(Node(term: Term.trueValue)))
        algebra = .union(.unionIdentity, algebra)
        algebra = .innerJoin(algebra, .joinIdentity)
        algebra = .distinct(algebra)
        
        algebra = .filter(algebra, .node(Node(term: Term.trueValue)))
        algebra = .project(algebra, Set(["name"]))
        algebra = .order(algebra, [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))])
        
        var tripleCount = 0
        try algebra.walk { (a) in
            switch a {
            case .triple(_):
                tripleCount += 1
            default:
                break
            }
        }
        XCTAssertEqual(tripleCount, 1)
    }
    
    func testBind() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(iri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"))
        let person: Node = .bound(Term(iri: "http://xmlns.com/foaf/0.1/Person"))
        let name: Node = .bound(Term(iri: "http://xmlns.com/foaf/0.1/name"))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t1bound = TriplePattern(subject: subj, predicate: type, object: person)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        
        let algebra = Algebra.order(
            .project(
                .filter(
                    .distinct(
                        .innerJoin(
                            .union(
                                .unionIdentity,
                                .leftOuterJoin(
                                    .bgp([t1]),
                                    .triple(t2),
                                    .node(Node(term: Term.trueValue))
                                )
                            ),
                            .joinIdentity
                        )
                    ),
                    .node(Node(term: Term.trueValue))
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))]
        )
        
        XCTAssertEqual(algebra.inscope, Set(["name", "type"]))
        let r = try algebra.bind("type", to: Node(term: Term(iri: "http://xmlns.com/foaf/0.1/Person")), preservingProjection: true)
        let expected = Algebra.order(
            .project(
                .extend(
                    .filter(
                        .distinct(
                            .innerJoin(
                                .union(
                                    .unionIdentity,
                                    .leftOuterJoin(
                                        .bgp([t1bound]),
                                        .triple(t2),
                                        .node(Node(term: Term.trueValue))
                                    )
                                ),
                                .joinIdentity
                            )
                        ),
                        .node(Node(term: Term.trueValue))
                    ),
                    .node(person),
                    "type"
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))]
        )
        XCTAssertEqual(r, expected)
    }
    
    func testReplacementMap() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(iri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"))
        let name: Node = .bound(Term(iri: "http://xmlns.com/foaf/0.1/name"))
        let eve: Node = .bound(Term(string: "Eve"))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        let t2replaced = TriplePattern(subject: subj, predicate: name, object: eve)

        let algebra = Algebra.order(
            .project(
                .filter(
                    .distinct(
                        .innerJoin(
                            .union(
                                .unionIdentity,
                                .leftOuterJoin(
                                    .bgp([t1]),
                                    .triple(t2),
                                    .node(Node(term: Term.trueValue))
                                )
                            ),
                            .joinIdentity
                        )
                    ),
                    .node(Node(term: Term.trueValue))
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))]
        )
        
        let r = try algebra.replace(["name": Term(string: "Eve")])
        let expected = Algebra.order(
            .project(
                .filter(
                    .distinct(
                        .innerJoin(
                            .union(
                                .unionIdentity,
                                .leftOuterJoin(
                                    .bgp([t1]),
                                    .triple(t2replaced),
                                    .node(Node(term: Term.trueValue))
                                )
                            ),
                            .joinIdentity
                        )
                    ),
                    .node(Node(term: Term.trueValue))
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: .node(eve))]
        )
        XCTAssertEqual(r, expected)
    }
    
    func testReplacementFunc() throws {
        let subj: Node = .bound(Term(value: "b", type: .blank))
        let type: Node = .bound(Term(iri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"))
        let name: Node = .bound(Term(iri: "http://xmlns.com/foaf/0.1/name"))
        let vtype: Node = .variable("type", binding: true)
        let vname: Node = .variable("name", binding: true)
        let t1 = TriplePattern(subject: subj, predicate: type, object: vtype)
        let t2 = TriplePattern(subject: subj, predicate: name, object: vname)
        
        let algebra = Algebra.order(
            .project(
                .filter(
                    .distinct(
                        .innerJoin(
                            .union(
                                .unionIdentity,
                                .leftOuterJoin(
                                    .bgp([t1]),
                                    .triple(t2),
                                    .node(Node(term: Term.trueValue))
                                )
                            ),
                            .joinIdentity
                        )
                    ),
                    .node(Node(term: Term.trueValue))
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))]
        )
        
        let r = try algebra.replace { (a) -> Algebra? in
            switch a {
            case .triple(let t):
                return .bgp([t])
            default:
                return nil
            }
        }
        let expected = Algebra.order(
            .project(
                .filter(
                    .distinct(
                        .innerJoin(
                            .union(
                                .unionIdentity,
                                .leftOuterJoin(
                                    .bgp([t1]),
                                    .bgp([t2]),
                                    .node(Node(term: Term.trueValue))
                                )
                            ),
                            .joinIdentity
                        )
                    ),
                    .node(Node(term: Term.trueValue))
                ),
                Set(["type", "name"])
            ),
            [Algebra.SortComparator(ascending: true, expression: Expression(variable: "name"))]
        )
        XCTAssertEqual(r, expected)
    }
    
}
