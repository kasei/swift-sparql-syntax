import XCTest
import Foundation
@testable import SPARQLSyntax

#if os(Linux)
extension ExpressionTest {
    static var allTests : [(String, (ExpressionTest) -> () throws -> Void)] {
        return [
            ("testRemoveAggregation", testRemoveAggregation),
        ]
    }
}
#endif

// swiftlint:disable type_body_length
class ExpressionTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func wrapDeepExpression(_ expr : Expression) -> Expression {
        let v1 = Expression(variable: "v1")
        let v2 = Expression.node(.variable("v2", binding: false))

        let l1 = Expression.node(.bound(Term(string: "en-US")))

        let i1 = Expression(integer: 1)
        let i2 = Expression.node(.bound(Term(integer: 2)))
        let i3 = Expression.node(.bound(Term(integer: 3)))

        let call1 = Expression.call("tag:kasei.us,2018:example-function", [])
        
        var e = expr
        
        e = .div(.sub(.mul(i2, .add(.neg(expr), i1)), i3), i1)
        e = .between(e, i1, i2)
        e = .not(e)
        e = .and(e, .bound(v2))
        e = .or(e, .lt(v1, i2))
        e = .and(e, .isiri(v1))
        e = .and(e, .isblank(v1))
        e = .and(e, .isliteral(v1))
        e = .and(e, .isnumeric(v1))
        e = .and(e, .langmatches(.lang(.stringCast(v2)), l1))
        e = .and(e, .boolCast(call1))
        e = .and(e, .eq(v1, .intCast(v2)))
        e = .and(e, .ne(v1, .floatCast(v2)))
        e = .and(e, .lt(v1, .doubleCast(v2)))
        e = .and(e, .le(v1, .decimalCast(v2)))
        e = .and(e, .gt(v1, v2))
        e = .and(e, .ge(v1, v2))
        e = .and(e, .sameterm(.datatype(v1), v2))
        e = .and(e, .valuein(v2, [i1, i2]))

        /**
         case dateTimeCast(Expression)
         case dateCast(Expression)
         case valuein(Expression, [Expression])
         case exists(Algebra)

 **/
        return e
    }
    
    func testBuiltInExpression() {
        let v1 = Expression.node(.variable("v1", binding: false))
        XCTAssertTrue(Expression.isiri(v1).isBuiltInCall)
        XCTAssertFalse(Expression.call("http://example.org/test-function", [v1]).isBuiltInCall)
    }
    
    func testIsNumeric() {
        let v1 = Expression(variable: "v1")
        let i1 = Expression(integer: 1)
        let i2 = Expression(integer: 2)
        XCTAssertFalse(Expression.isiri(v1).isNumeric)
        XCTAssertFalse(Expression.add(v1, i1).isNumeric)
        XCTAssertTrue(Expression.add(.intCast(i2), i1).isNumeric)
    }
    
    func testRemoveAggregation() {
        let freshCounter = AnyIterator(sequence(first: 1) { $0 + 1 })
        let agg : Aggregation = .sum(.node(.variable("var", binding: true)), false)
        let expr = wrapDeepExpression(.aggregate(agg))
        XCTAssertEqual(expr.variables, Set(["v1", "v2", "var"]))
        XCTAssertTrue(expr.hasAggregation)
        let expected = wrapDeepExpression(.node(.variable(".agg-1", binding: true)))
        var mapping = [String:Aggregation]()
        let r = expr.removeAggregations(freshCounter, mapping: &mapping)
        XCTAssertFalse(r.hasAggregation)
        XCTAssertEqual(r.variables, Set(["v1", "v2", ".agg-1"]))
        XCTAssertEqual(r, expected)
        XCTAssertEqual(mapping, [".agg-1": agg])
    }

    func testReplacementDeepMap() throws {
        let agg : Aggregation = .sum(.node(.variable("var", binding: true)), false)
        let expr = wrapDeepExpression(.aggregate(agg))
        XCTAssertEqual(expr.description, """
        ((((((((((((((((NOT(((((2 * (-(SUM(?var)) + 1)) - 3) / 1) BETWEEN 1 AND 2)) && BOUND(?v2)) || (?v1 < 2)) && ISIRI(?v1)) && ISBLANK(?v1)) && ISLITERAL(?v1)) && ISNUMERIC(?v1)) && LANGMATCHES(LANG(xsd:string(?v2)), ""en-US"")) && xsd:boolean(<tag:kasei.us,2018:example-function>())) && (?v1 == xsd:integer(?v2))) && (?v1 != xsd:float(?v2))) && (?v1 < xsd:double(?v2))) && (?v1 <= xsd:decimal(?v2))) && (?v1 > ?v2)) && (?v1 >= ?v2)) && SAMETERM(DATATYPE(?v1), ?v2)) && ?v2 IN (1,2))
        """)
        let r = try expr.replace(["var": Term(integer: 2)])
        XCTAssertEqual(r.description, """
        ((((((((((((((((NOT(((((2 * (-(SUM(2)) + 1)) - 3) / 1) BETWEEN 1 AND 2)) && BOUND(?v2)) || (?v1 < 2)) && ISIRI(?v1)) && ISBLANK(?v1)) && ISLITERAL(?v1)) && ISNUMERIC(?v1)) && LANGMATCHES(LANG(xsd:string(?v2)), ""en-US"")) && xsd:boolean(<tag:kasei.us,2018:example-function>())) && (?v1 == xsd:integer(?v2))) && (?v1 != xsd:float(?v2))) && (?v1 < xsd:double(?v2))) && (?v1 <= xsd:decimal(?v2))) && (?v1 > ?v2)) && (?v1 >= ?v2)) && SAMETERM(DATATYPE(?v1), ?v2)) && ?v2 IN (1,2))
        """)
    }
    
    func testReplacementMap() throws {
        let agg : Aggregation = .sum(.node(.variable("var", binding: true)), false)
        let expr = Expression.add(Expression(integer: 2), .aggregate(agg))
        XCTAssertEqual(expr.description, "(2 + SUM(?var))")
        let r = try expr.replace(["var": Term(integer: 2)])
        XCTAssertEqual(r.description, "(2 + SUM(2))")
    }
    
    func testReplacementFunc() throws {
        let agg : Aggregation = .sum(.node(.variable("var", binding: true)), false)
        let expr = wrapDeepExpression(.aggregate(agg))
        let r = try expr.replace { (e) -> Expression? in
            switch e {
            case .and(_, _):
                return Expression(variable: "xxx")
            default:
                return e
            }
        }
        XCTAssertEqual(r, Expression(variable: "xxx"))
    }

    func testEncodable() throws {
        let agg : Aggregation = .sum(.node(.variable("var", binding: true)), false)
        let expr = wrapDeepExpression(.aggregate(agg))
        let je = JSONEncoder()
        let jd = JSONDecoder()
        let data = try je.encode(expr)
        let r = try jd.decode(Expression.self, from: data)
        XCTAssertEqual(r.description, """
        ((((((((((((((((NOT(((((2 * (-(SUM(?var)) + 1)) - 3) / 1) BETWEEN 1 AND 2)) && BOUND(?v2)) || (?v1 < 2)) && ISIRI(?v1)) && ISBLANK(?v1)) && ISLITERAL(?v1)) && ISNUMERIC(?v1)) && LANGMATCHES(LANG(xsd:string(?v2)), ""en-US"")) && xsd:boolean(<tag:kasei.us,2018:example-function>())) && (?v1 == xsd:integer(?v2))) && (?v1 != xsd:float(?v2))) && (?v1 < xsd:double(?v2))) && (?v1 <= xsd:decimal(?v2))) && (?v1 > ?v2)) && (?v1 >= ?v2)) && SAMETERM(DATATYPE(?v1), ?v2)) && ?v2 IN (1,2))
        """)
    }
}
