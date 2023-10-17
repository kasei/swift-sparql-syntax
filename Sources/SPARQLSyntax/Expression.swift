//
//  Expression.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 7/31/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable:next type_body_length
public indirect enum Expression: Equatable, Hashable, CustomStringConvertible {
    static let trueExpression: Expression = .node(.bound(Term.trueValue))
    static let falseExpression: Expression = .node(.bound(Term.falseValue))

    case node(Node)
    case window(WindowApplication)
    case aggregate(Aggregation)
    case neg(Expression)
    case not(Expression)
    case isiri(Expression)
    case isblank(Expression)
    case isliteral(Expression)
    case isnumeric(Expression)
    case lang(Expression)
    case langmatches(Expression, Expression)
    case datatype(Expression)
    case sameterm(Expression, Expression)
    case bound(Expression)
    case boolCast(Expression)
    case intCast(Expression)
    case floatCast(Expression)
    case doubleCast(Expression)
    case decimalCast(Expression)
    case dateTimeCast(Expression)
    case dateCast(Expression)
    case stringCast(Expression)
    case eq(Expression, Expression)
    case ne(Expression, Expression)
    case lt(Expression, Expression)
    case le(Expression, Expression)
    case gt(Expression, Expression)
    case ge(Expression, Expression)
    case add(Expression, Expression)
    case sub(Expression, Expression)
    case div(Expression, Expression)
    case mul(Expression, Expression)
    case and(Expression, Expression)
    case or(Expression, Expression)
    case between(Expression, Expression, Expression)
    case valuein(Expression, [Expression])
    case call(String, [Expression])
    case exists(Algebra)
    
    public init(variable name: String) {
        self = .node(.variable(name, binding: true))
    }
    
    public init(integer value: Int) {
        self = .node(.bound(Term(integer: value)))
    }
    
    public var variables: Set<String> {
        switch self {
        case .node(.variable(let s, binding: _)):
            return Set([s])
        case .node(_):
            return Set()
        case .not(let expr), .isiri(let expr), .isblank(let expr), .isliteral(let expr), .isnumeric(let expr), .lang(let expr), .datatype(let expr), .bound(let expr), .boolCast(let expr), .intCast(let expr), .floatCast(let expr), .doubleCast(let expr), .decimalCast(let expr), .dateTimeCast(let expr), .dateCast(let expr), .stringCast(let expr), .neg(let expr):
            return expr.variables
        case .eq(let lhs, let rhs), .ne(let lhs, let rhs), .lt(let lhs, let rhs), .le(let lhs, let rhs), .gt(let lhs, let rhs), .ge(let lhs, let rhs), .add(let lhs, let rhs), .sub(let lhs, let rhs), .div(let lhs, let rhs), .mul(let lhs, let rhs), .and(let lhs, let rhs), .or(let lhs, let rhs), .langmatches(let lhs, let rhs), .sameterm(let lhs, let rhs):
            return lhs.variables.union(rhs.variables)
        case .between(let a, let b, let c):
            return a.variables.union(b.variables).union(c.variables)
        case .call(_, let exprs):
            return exprs.reduce(Set()) { $0.union($1.variables) }
        case .valuein(let expr, let exprs):
            return exprs.reduce(expr.variables) { $0.union($1.variables) }
        case .aggregate(let a):
            return a.variables
        case .window(let w):
            return w.variables
        case .exists(let p):
            return p.inscope
        }
    }
    
    public var hasAggregation: Bool {
        switch self {
        case .aggregate(_):
            return true
        case .window(_):
            return false
        case .node(_), .exists(_):
            return false
        case .not(let expr), .isiri(let expr), .isblank(let expr), .isliteral(let expr), .isnumeric(let expr), .lang(let expr), .datatype(let expr), .bound(let expr), .boolCast(let expr), .intCast(let expr), .floatCast(let expr), .doubleCast(let expr), .decimalCast(let expr), .dateTimeCast(let expr), .dateCast(let expr), .stringCast(let expr), .neg(let expr):
            return expr.hasAggregation
        case .eq(let lhs, let rhs), .ne(let lhs, let rhs), .lt(let lhs, let rhs), .le(let lhs, let rhs), .gt(let lhs, let rhs), .ge(let lhs, let rhs), .add(let lhs, let rhs), .sub(let lhs, let rhs), .div(let lhs, let rhs), .mul(let lhs, let rhs), .and(let lhs, let rhs), .or(let lhs, let rhs), .langmatches(let lhs, let rhs), .sameterm(let lhs, let rhs):
            return lhs.hasAggregation || rhs.hasAggregation
        case .between(let a, let b, let c):
            return a.hasAggregation || b.hasAggregation || c.hasAggregation
        case .call(_, let exprs):
            return exprs.reduce(false) { $0 || $1.hasAggregation }
        case .valuein(let expr, let exprs):
            return exprs.reduce(expr.hasAggregation) { $0 || $1.hasAggregation }
        }
    }
    
    func removeAggregations(_ counter: AnyIterator<Int>, mapping: inout [String:Aggregation]) -> Expression {
        switch self {
        case .node(_), .exists(_):
            return self
        case .neg(let expr):
            return .neg(expr.removeAggregations(counter, mapping: &mapping))
        case .not(let expr):
            return .not(expr.removeAggregations(counter, mapping: &mapping))
        case .isiri(let expr):
            return .isiri(expr.removeAggregations(counter, mapping: &mapping))
        case .isblank(let expr):
            return .isblank(expr.removeAggregations(counter, mapping: &mapping))
        case .isliteral(let expr):
            return .isliteral(expr.removeAggregations(counter, mapping: &mapping))
        case .isnumeric(let expr):
            return .isnumeric(expr.removeAggregations(counter, mapping: &mapping))
        case .lang(let expr):
            return .lang(expr.removeAggregations(counter, mapping: &mapping))
        case .langmatches(let expr, let pattern):
            return .langmatches(expr.removeAggregations(counter, mapping: &mapping), pattern.removeAggregations(counter, mapping: &mapping))
        case .sameterm(let expr, let pattern):
            return .sameterm(expr.removeAggregations(counter, mapping: &mapping), pattern.removeAggregations(counter, mapping: &mapping))
        case .datatype(let expr):
            return .datatype(expr.removeAggregations(counter, mapping: &mapping))
        case .bound(let expr):
            return .bound(expr.removeAggregations(counter, mapping: &mapping))
        case .boolCast(let expr):
            return .boolCast(expr.removeAggregations(counter, mapping: &mapping))
        case .intCast(let expr):
            return .intCast(expr.removeAggregations(counter, mapping: &mapping))
        case .floatCast(let expr):
            return .floatCast(expr.removeAggregations(counter, mapping: &mapping))
        case .doubleCast(let expr):
            return .doubleCast(expr.removeAggregations(counter, mapping: &mapping))
        case .decimalCast(let expr):
            return .decimalCast(expr.removeAggregations(counter, mapping: &mapping))
        case .dateTimeCast(let expr):
            return .dateTimeCast(expr.removeAggregations(counter, mapping: &mapping))
        case .dateCast(let expr):
            return .dateCast(expr.removeAggregations(counter, mapping: &mapping))
        case .stringCast(let expr):
            return .stringCast(expr.removeAggregations(counter, mapping: &mapping))
        case .call(let f, let exprs):
            return .call(f, exprs.map { $0.removeAggregations(counter, mapping: &mapping) })
        case .eq(let lhs, let rhs):
            return .eq(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .ne(let lhs, let rhs):
            return .ne(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .lt(let lhs, let rhs):
            return .lt(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .le(let lhs, let rhs):
            return .le(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .gt(let lhs, let rhs):
            return .gt(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .ge(let lhs, let rhs):
            return .ge(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .add(let lhs, let rhs):
            return .add(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .sub(let lhs, let rhs):
            return .sub(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .div(let lhs, let rhs):
            return .div(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .mul(let lhs, let rhs):
            return .mul(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .and(let lhs, let rhs):
            return .and(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .or(let lhs, let rhs):
            return .or(lhs.removeAggregations(counter, mapping: &mapping), rhs.removeAggregations(counter, mapping: &mapping))
        case .between(let a, let b, let c):
            return .between(a.removeAggregations(counter, mapping: &mapping), b.removeAggregations(counter, mapping: &mapping), c.removeAggregations(counter, mapping: &mapping))
        case .aggregate(let agg):
            guard let c = counter.next() else { fatalError("No fresh variable available") }
            let name = ".agg-\(c)"
            mapping[name] = agg
            let node: Node = .variable(name, binding: true)
            return .node(node)
        case .window(let w):
            return .window(w)
        case .valuein(let expr, let exprs):
            return .valuein(expr.removeAggregations(counter, mapping: &mapping), exprs.map { $0.removeAggregations(counter, mapping: &mapping) })
        }
    }
    
    public var hasWindow: Bool {
        switch self {
        case .aggregate(_):
            return false
        case .window(_):
            return true
        case .node(_), .exists(_):
            return false
        case .not(let expr), .isiri(let expr), .isblank(let expr), .isliteral(let expr), .isnumeric(let expr), .lang(let expr), .datatype(let expr), .bound(let expr), .boolCast(let expr), .intCast(let expr), .floatCast(let expr), .doubleCast(let expr), .decimalCast(let expr), .dateTimeCast(let expr), .dateCast(let expr), .stringCast(let expr), .neg(let expr):
            return expr.hasWindow
        case .eq(let lhs, let rhs), .ne(let lhs, let rhs), .lt(let lhs, let rhs), .le(let lhs, let rhs), .gt(let lhs, let rhs), .ge(let lhs, let rhs), .add(let lhs, let rhs), .sub(let lhs, let rhs), .div(let lhs, let rhs), .mul(let lhs, let rhs), .and(let lhs, let rhs), .or(let lhs, let rhs), .langmatches(let lhs, let rhs), .sameterm(let lhs, let rhs):
            return lhs.hasWindow || rhs.hasWindow
        case .between(let a, let b, let c):
            return a.hasWindow || b.hasWindow || c.hasWindow
        case .call(_, let exprs):
            return exprs.reduce(false) { $0 || $1.hasWindow }
        case .valuein(let expr, let exprs):
            return exprs.reduce(expr.hasWindow) { $0 || $1.hasWindow }
        }
    }
    
    func removeWindows(_ counter: AnyIterator<Int>, mapping: inout [String:WindowApplication]) -> Expression {
        switch self {
        case .node(_), .exists(_):
            return self
        case .neg(let expr):
            return .neg(expr.removeWindows(counter, mapping: &mapping))
        case .not(let expr):
            return .not(expr.removeWindows(counter, mapping: &mapping))
        case .isiri(let expr):
            return .isiri(expr.removeWindows(counter, mapping: &mapping))
        case .isblank(let expr):
            return .isblank(expr.removeWindows(counter, mapping: &mapping))
        case .isliteral(let expr):
            return .isliteral(expr.removeWindows(counter, mapping: &mapping))
        case .isnumeric(let expr):
            return .isnumeric(expr.removeWindows(counter, mapping: &mapping))
        case .lang(let expr):
            return .lang(expr.removeWindows(counter, mapping: &mapping))
        case .langmatches(let expr, let pattern):
            return .langmatches(expr.removeWindows(counter, mapping: &mapping), pattern.removeWindows(counter, mapping: &mapping))
        case .sameterm(let expr, let pattern):
            return .sameterm(expr.removeWindows(counter, mapping: &mapping), pattern.removeWindows(counter, mapping: &mapping))
        case .datatype(let expr):
            return .datatype(expr.removeWindows(counter, mapping: &mapping))
        case .bound(let expr):
            return .bound(expr.removeWindows(counter, mapping: &mapping))
        case .boolCast(let expr):
            return .boolCast(expr.removeWindows(counter, mapping: &mapping))
        case .intCast(let expr):
            return .intCast(expr.removeWindows(counter, mapping: &mapping))
        case .floatCast(let expr):
            return .floatCast(expr.removeWindows(counter, mapping: &mapping))
        case .doubleCast(let expr):
            return .doubleCast(expr.removeWindows(counter, mapping: &mapping))
        case .decimalCast(let expr):
            return .decimalCast(expr.removeWindows(counter, mapping: &mapping))
        case .dateTimeCast(let expr):
            return .dateTimeCast(expr.removeWindows(counter, mapping: &mapping))
        case .dateCast(let expr):
            return .dateCast(expr.removeWindows(counter, mapping: &mapping))
        case .stringCast(let expr):
            return .stringCast(expr.removeWindows(counter, mapping: &mapping))
        case .call(let f, let exprs):
            return .call(f, exprs.map { $0.removeWindows(counter, mapping: &mapping) })
        case .eq(let lhs, let rhs):
            return .eq(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .ne(let lhs, let rhs):
            return .ne(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .lt(let lhs, let rhs):
            return .lt(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .le(let lhs, let rhs):
            return .le(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .gt(let lhs, let rhs):
            return .gt(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .ge(let lhs, let rhs):
            return .ge(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .add(let lhs, let rhs):
            return .add(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .sub(let lhs, let rhs):
            return .sub(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .div(let lhs, let rhs):
            return .div(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .mul(let lhs, let rhs):
            return .mul(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .and(let lhs, let rhs):
            return .and(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .or(let lhs, let rhs):
            return .or(lhs.removeWindows(counter, mapping: &mapping), rhs.removeWindows(counter, mapping: &mapping))
        case .between(let a, let b, let c):
            return .between(a.removeWindows(counter, mapping: &mapping), b.removeWindows(counter, mapping: &mapping), c.removeWindows(counter, mapping: &mapping))
        case .aggregate(let agg):
            return .aggregate(agg)
        case .window(let w):
            guard let c = counter.next() else { fatalError("No fresh variable available") }
            let name = ".window-\(c)"
            mapping[name] = w
            let node: Node = .variable(name, binding: true)
            return .node(node)
        case .valuein(let expr, let exprs):
            return .valuein(expr.removeWindows(counter, mapping: &mapping), exprs.map { $0.removeWindows(counter, mapping: &mapping) })
        }
    }
    
    var isBuiltInCall: Bool {
        switch self {
        case .aggregate, .stringCast, .lang, .langmatches, .datatype, .bound, .call("IRI", _), .call("BNODE", _), .call("RAND", _), .call("ABS", _), .call("CEIL", _), .call("FLOOR", _), .call("ROUND", _), .call("CONCAT", _), .call("STRLEN", _), .call("UCASE", _), .call("LCASE", _), .call("ENCODE_FOR_URI", _), .call("CONTAINS", _), .call("STRSTARTS", _), .call("STRENDS", _), .call("STRBEFORE", _), .call("STRAFTER", _), .call("YEAR", _), .call("MONTH", _), .call("DAY", _), .call("HOURS", _), .call("MINUTES", _), .call("SECONDS", _), .call("TIMEZONE", _), .call("TZ", _), .call("NOW", _), .call("UUID", _), .call("STRUUID", _), .call("MD5", _), .call("SHA1", _), .call("SHA256", _), .call("SHA384", _), .call("SHA512", _), .call("COALESCE", _), .call("IF", _), .call("STRLANG", _), .call("STRDT", _), .sameterm(_, _), .isiri, .isblank, .isliteral, .isnumeric, .call("REGEX", _), .exists, .not(.exists):
            return true
        default:
            return false
        }
    }

    public var isNumeric: Bool {
        switch self {
        case .node(.bound(let term)) where term.isNumeric:
            return true
        case .neg(let expr):
            return expr.isNumeric
        case .add(let l, let r), .sub(let l, let r), .div(let l, let r), .mul(let l, let r):
            return l.isNumeric && r.isNumeric
        case .intCast(let expr), .floatCast(let expr), .doubleCast(let expr):
            return expr.isNumeric
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .aggregate(let a):
            return a.description
        case .window(let w):
            return w.description
        case .node(let node):
            return node.description
        case .eq(let lhs, let rhs):
            return "(\(lhs) == \(rhs))"
        case .ne(let lhs, let rhs):
            return "(\(lhs) != \(rhs))"
        case .gt(let lhs, let rhs):
            return "(\(lhs) > \(rhs))"
        case .between(let val, let lower, let upper):
            return "(\(val) BETWEEN \(lower) AND \(upper))"
        case .lt(let lhs, let rhs):
            return "(\(lhs) < \(rhs))"
        case .ge(let lhs, let rhs):
            return "(\(lhs) >= \(rhs))"
        case .le(let lhs, let rhs):
            return "(\(lhs) <= \(rhs))"
        case .add(let lhs, let rhs):
            return "(\(lhs) + \(rhs))"
        case .sub(let lhs, let rhs):
            return "(\(lhs) - \(rhs))"
        case .mul(let lhs, let rhs):
            return "(\(lhs) * \(rhs))"
        case .div(let lhs, let rhs):
            return "(\(lhs) / \(rhs))"
        case .neg(let expr):
            return "-(\(expr))"
        case .and(let lhs, let rhs):
            return "(\(lhs) && \(rhs))"
        case .or(let lhs, let rhs):
            return "(\(lhs) || \(rhs))"
        case .isiri(let expr):
            return "ISIRI(\(expr))"
        case .isblank(let expr):
            return "ISBLANK(\(expr))"
        case .isliteral(let expr):
            return "ISLITERAL(\(expr))"
        case .isnumeric(let expr):
            return "ISNUMERIC(\(expr))"
        case .boolCast(let expr):
            return "xsd:boolean(\(expr.description))"
        case .intCast(let expr):
            return "xsd:integer(\(expr.description))"
        case .floatCast(let expr):
            return "xsd:float(\(expr.description))"
        case .doubleCast(let expr):
            return "xsd:double(\(expr.description))"
        case .decimalCast(let expr):
            return "xsd:decimal(\(expr.description))"
        case .dateTimeCast(let expr):
            return "xsd:dateTime(\(expr.description))"
        case .dateCast(let expr):
            return "xsd:date(\(expr.description))"
        case .stringCast(let expr):
            return "xsd:string(\(expr.description))"
        case .call(let iri, let exprs):
            let strings = exprs.map { $0.description }
            return "<\(iri)>(\(strings.joined(separator: ",")))"
        case .lang(let expr):
            return "LANG(\(expr))"
        case .langmatches(let expr, let m):
            return "LANGMATCHES(\(expr), \"\(m)\")"
        case .sameterm(let lhs, let rhs):
            return "SAMETERM(\(lhs), \(rhs))"
        case .datatype(let expr):
            return "DATATYPE(\(expr))"
        case .bound(let expr):
            return "BOUND(\(expr))"
        case .not(.valuein(let expr, let exprs)):
            let strings = exprs.map { $0.description }
            return "\(expr) NOT IN (\(strings.joined(separator: ",")))"
        case .valuein(let expr, let exprs):
            let strings = exprs.map { $0.description }
            return "\(expr) IN (\(strings.joined(separator: ",")))"
        case .not(.exists(let child)):
            return "NOT EXISTS { \(child) }"
        case .not(let expr):
            return "NOT(\(expr))"
        case .exists(let child):
            return "EXISTS { \(child) }"
        }
    }
}

extension Expression: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case node
        case lhs
        case rhs
        case value
        case algebra
        case name
        case expressions
        case aggregate
        case window
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "node":
            let node = try container.decode(Node.self, forKey: .node)
            self = .node(node)
        case "aggregate":
            let agg = try container.decode(Aggregation.self, forKey: .aggregate)
            self = .aggregate(agg)
        case "window":
            let window = try container.decode(WindowApplication.self, forKey: .window)
            self = .window(window)
        case "neg":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .neg(lhs)
        case "not":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .not(lhs)
        case "isiri":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .isiri(lhs)
        case "isblank":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .isblank(lhs)
        case "isliteral":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .isliteral(lhs)
        case "isnumeric":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .isnumeric(lhs)
        case "lang":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .lang(lhs)
        case "langmatches":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .langmatches(lhs, rhs)
        case "datatype":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .datatype(lhs)
        case "sameterm":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .sameterm(lhs, rhs)
        case "bound":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .bound(lhs)
        case "bool":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .boolCast(lhs)
        case "int":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .intCast(lhs)
        case "float":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .floatCast(lhs)
        case "double":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .doubleCast(lhs)
        case "decimal":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .decimalCast(lhs)
        case "dateTime":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .dateTimeCast(lhs)
        case "date":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .dateCast(lhs)
        case "string":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            self = .stringCast(lhs)
        case "eq":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .eq(lhs, rhs)
        case "ne":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .ne(lhs, rhs)
        case "lt":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .lt(lhs, rhs)
        case "le":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .le(lhs, rhs)
        case "gt":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .gt(lhs, rhs)
        case "ge":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .ge(lhs, rhs)
        case "add":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .add(lhs, rhs)
        case "sub":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .sub(lhs, rhs)
        case "div":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .div(lhs, rhs)
        case "mul":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .mul(lhs, rhs)
        case "and":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .and(lhs, rhs)
        case "or":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .or(lhs, rhs)
        case "between":
            let value = try container.decode(Expression.self, forKey: .value)
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let rhs = try container.decode(Expression.self, forKey: .rhs)
            self = .between(value, lhs, rhs)
        case "valuein":
            let lhs = try container.decode(Expression.self, forKey: .lhs)
            let exprs = try container.decode([Expression].self, forKey: .expressions)
            self = .valuein(lhs, exprs)
        case "call":
            let name = try container.decode(String.self, forKey: .name)
            let exprs = try container.decode([Expression].self, forKey: .expressions)
            self = .call(name, exprs)
        case "exists":
            let algebra = try container.decode(Algebra.self, forKey: .algebra)
            self = .exists(algebra)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected expression type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .node(node):
            try container.encode("node", forKey: .type)
            try container.encode(node, forKey: .node)
        case let .aggregate(agg):
            try container.encode("aggregate", forKey: .type)
            try container.encode(agg, forKey: .aggregate)
        case let .window(window):
            try container.encode("window", forKey: .type)
            try container.encode(window, forKey: .window)
        case let .neg(lhs):
            try container.encode("neg", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .not(lhs):
            try container.encode("not", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .isiri(lhs):
            try container.encode("isiri", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .isblank(lhs):
            try container.encode("isblank", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .isliteral(lhs):
            try container.encode("isliteral", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .isnumeric(lhs):
            try container.encode("isnumeric", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .lang(lhs):
            try container.encode("lang", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .langmatches(lhs, rhs):
            try container.encode("langmatches", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .datatype(lhs):
            try container.encode("datatype", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .sameterm(lhs, rhs):
            try container.encode("sameterm", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .bound(lhs):
            try container.encode("bound", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .boolCast(lhs):
            try container.encode("bool", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .intCast(lhs):
            try container.encode("int", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .floatCast(lhs):
            try container.encode("float", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .doubleCast(lhs):
            try container.encode("double", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .decimalCast(lhs):
            try container.encode("decimal", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .dateTimeCast(lhs):
            try container.encode("dateTime", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .dateCast(lhs):
            try container.encode("date", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .stringCast(lhs):
            try container.encode("string", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .eq(lhs, rhs):
            try container.encode("eq", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .ne(lhs, rhs):
            try container.encode("ne", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .lt(lhs, rhs):
            try container.encode("lt", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .le(lhs, rhs):
            try container.encode("le", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .gt(lhs, rhs):
            try container.encode("gt", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .ge(lhs, rhs):
            try container.encode("ge", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .add(lhs, rhs):
            try container.encode("add", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .sub(lhs, rhs):
            try container.encode("sub", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .div(lhs, rhs):
            try container.encode("div", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .mul(lhs, rhs):
            try container.encode("mul", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .and(lhs, rhs):
            try container.encode("and", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .or(lhs, rhs):
            try container.encode("or", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .between(value, lhs, rhs):
            try container.encode("between", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .valuein(lhs, exprs):
            try container.encode("valuein", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(exprs, forKey: .expressions)
        case let .call(name, exprs):
            try container.encode("call", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(exprs, forKey: .expressions)
        case let .exists(algebra):
            try container.encode("exists", forKey: .type)
            try container.encode(algebra, forKey: .algebra)
        }
    }
}

public extension Expression {
    func replace(_ map: [String:Term]) throws -> Expression {
        let nodes = map.mapValues { Node.bound($0) }
        return try self.replace(nodes)
    }
    
    func replace(_ map: [String:Node]) throws -> Expression {
        return try self.replace({ (e) -> Expression? in
            switch e {
            case let .node(.variable(name, _)):
                if let n = map[name] {
                    return .node(n)
                } else {
                    return e
                }
            case .node(_):
                return self
            case .aggregate(let a):
                return try .aggregate(a.replace(map))
            case .window(let w):
                return try .window(w.replace(map))
            case .neg(let expr):
                return try .neg(expr.replace(map))
            case .eq(let lhs, let rhs):
                return try .eq(lhs.replace(map), rhs.replace(map))
            case .ne(let lhs, let rhs):
                return try .ne(lhs.replace(map), rhs.replace(map))
            case .gt(let lhs, let rhs):
                return try .gt(lhs.replace(map), rhs.replace(map))
            case .lt(let lhs, let rhs):
                return try .lt(lhs.replace(map), rhs.replace(map))
            case .ge(let lhs, let rhs):
                return try .ge(lhs.replace(map), rhs.replace(map))
            case .le(let lhs, let rhs):
                return try .le(lhs.replace(map), rhs.replace(map))
            case .add(let lhs, let rhs):
                return try .add(lhs.replace(map), rhs.replace(map))
            case .sub(let lhs, let rhs):
                return try .sub(lhs.replace(map), rhs.replace(map))
            case .mul(let lhs, let rhs):
                return try .mul(lhs.replace(map), rhs.replace(map))
            case .div(let lhs, let rhs):
                return try .div(lhs.replace(map), rhs.replace(map))
            case .between(let val, let lower, let upper):
                return try .between(val.replace(map), lower.replace(map), upper.replace(map))
            case .and(let lhs, let rhs):
                return try .and(lhs.replace(map), rhs.replace(map))
            case .or(let lhs, let rhs):
                return try .or(lhs.replace(map), rhs.replace(map))
            case .isiri(let expr):
                return try .isiri(expr.replace(map))
            case .isblank(let expr):
                return try .isblank(expr.replace(map))
            case .isliteral(let expr):
                return try .isliteral(expr.replace(map))
            case .isnumeric(let expr):
                return try .isnumeric(expr.replace(map))
            case .boolCast(let expr):
                return try .boolCast(expr.replace(map))
            case .intCast(let expr):
                return try .intCast(expr.replace(map))
            case .floatCast(let expr):
                return try .floatCast(expr.replace(map))
            case .doubleCast(let expr):
                return try .doubleCast(expr.replace(map))
            case .decimalCast(let expr):
                return try .decimalCast(expr.replace(map))
            case .dateTimeCast(let expr):
                return try .dateTimeCast(expr.replace(map))
            case .dateCast(let expr):
                return try .dateCast(expr.replace(map))
            case .stringCast(let expr):
                return try .stringCast(expr.replace(map))
            case .call(let iri, let exprs):
                return try .call(iri, exprs.map { try $0.replace(map) })
            case .lang(let expr):
                return try .lang(expr.replace(map))
            case .langmatches(let expr, let m):
                return try .langmatches(expr.replace(map), m)
            case .sameterm(let lhs, let rhs):
                return try .sameterm(lhs.replace(map), rhs.replace(map))
            case .datatype(let expr):
                return try .datatype(expr.replace(map))
            case .bound(let expr):
                return try .bound(expr.replace(map))
            case .valuein(let expr, let exprs):
                return try .valuein(expr.replace(map), exprs.map { try $0.replace(map) })
            case .not(let expr):
                return try .not(expr.replace(map))
            case .exists(let a):
                return try .exists(a.replace(map))
            }
        })
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> Expression {
        return try self.rewrite { (e) -> RewriteStatus<Expression> in
            if let r = try map(e) {
                return .rewrite(r)
            } else {
                return .rewriteChildren(e)
            }
        }
    }

    func rewrite(_ map: (Expression) throws -> RewriteStatus<Expression>) throws -> Expression {
        let status = try map(self)
        switch status {
        case .keep:
            return self
        case .rewrite(let e):
            return e
        case .rewriteChildren(let e):
            switch e {
            case .node(_):
                return e
            case .aggregate(let a):
                return try .aggregate(a.rewrite(map))
            case .window(let w):
                return try .window(w.rewrite(map))
            case .neg(let expr):
                return try .neg(expr.rewrite(map))
            case .eq(let lhs, let rhs):
                return try .eq(lhs.rewrite(map), rhs.rewrite(map))
            case .ne(let lhs, let rhs):
                return try .ne(lhs.rewrite(map), rhs.rewrite(map))
            case .gt(let lhs, let rhs):
                return try .gt(lhs.rewrite(map), rhs.rewrite(map))
            case .lt(let lhs, let rhs):
                return try .lt(lhs.rewrite(map), rhs.rewrite(map))
            case .ge(let lhs, let rhs):
                return try .ge(lhs.rewrite(map), rhs.rewrite(map))
            case .le(let lhs, let rhs):
                return try .le(lhs.rewrite(map), rhs.rewrite(map))
            case .add(let lhs, let rhs):
                return try .add(lhs.rewrite(map), rhs.rewrite(map))
            case .sub(let lhs, let rhs):
                return try .sub(lhs.rewrite(map), rhs.rewrite(map))
            case .mul(let lhs, let rhs):
                return try .mul(lhs.rewrite(map), rhs.rewrite(map))
            case .div(let lhs, let rhs):
                return try .div(lhs.rewrite(map), rhs.rewrite(map))
            case .between(let val, let lower, let upper):
                return try .between(val.rewrite(map), lower.rewrite(map), upper.rewrite(map))
            case .and(let lhs, let rhs):
                return try .and(lhs.rewrite(map), rhs.rewrite(map))
            case .or(let lhs, let rhs):
                return try .or(lhs.rewrite(map), rhs.rewrite(map))
            case .isiri(let expr):
                return try .isiri(expr.rewrite(map))
            case .isblank(let expr):
                return try .isblank(expr.rewrite(map))
            case .isliteral(let expr):
                return try .isliteral(expr.rewrite(map))
            case .isnumeric(let expr):
                return try .isnumeric(expr.rewrite(map))
            case .boolCast(let expr):
                return try .boolCast(expr.rewrite(map))
            case .intCast(let expr):
                return try .intCast(expr.rewrite(map))
            case .floatCast(let expr):
                return try .floatCast(expr.rewrite(map))
            case .doubleCast(let expr):
                return try .doubleCast(expr.rewrite(map))
            case .decimalCast(let expr):
                return try .decimalCast(expr.rewrite(map))
            case .dateTimeCast(let expr):
                return try .dateTimeCast(expr.rewrite(map))
            case .dateCast(let expr):
                return try .dateCast(expr.rewrite(map))
            case .stringCast(let expr):
                return try .stringCast(expr.rewrite(map))
            case .call(let iri, let exprs):
                return try .call(iri, exprs.map { try $0.rewrite(map) })
            case .lang(let expr):
                return try .lang(expr.rewrite(map))
            case .langmatches(let expr, let m):
                return try .langmatches(expr.rewrite(map), m)
            case .sameterm(let lhs, let rhs):
                return try .sameterm(lhs.rewrite(map), rhs.rewrite(map))
            case .datatype(let expr):
                return try .datatype(expr.rewrite(map))
            case .bound(let expr):
                return try .bound(expr.rewrite(map))
            case .valuein(let expr, let exprs):
                return try .valuein(expr.rewrite(map), exprs.map { try $0.rewrite(map) })
            case .not(let expr):
                return try .not(expr.rewrite(map))
            case .exists(_):
                return e
            }
        }
    }
}

public extension Expression {
    func walk(_ handler: @escaping (Expression) throws -> ()) throws {
        let config = WalkConfig(type: .defaultType, expressionHandler: handler)
        try walk(config: config)
    }
    
    func walk(config: WalkConfig) throws {
        try config.handle(self)
        
        switch self {
        case .node:
            return
        case .window(let w):
            try w.comparators.forEach {
                try $0.expression.walk(config: config)
            }
            if let exprs = w.windowFunction.expressions {
                try exprs.forEach {
                    try $0.walk(config: config)
                }
            }
        case .aggregate(let a):
            if let e = a.expression {
                try e.walk(config: config)
            }
        case .neg(let e), .not(let e), .isiri(let e), .isblank(let e), .isliteral(let e), .isnumeric(let e), .lang(let e), .datatype(let e), .bound(let e), .boolCast(let e), .intCast(let e), .floatCast(let e), .doubleCast(let e), .decimalCast(let e), .dateTimeCast(let e), .dateCast(let e), .stringCast(let e):
            try e.walk(config: config)
            
        case .langmatches(let lhs, let rhs), .sameterm(let lhs, let rhs), .eq(let lhs, let rhs), .ne(let lhs, let rhs), .lt(let lhs, let rhs), .le(let lhs, let rhs), .gt(let lhs, let rhs), .ge(let lhs, let rhs), .add(let lhs, let rhs), .sub(let lhs, let rhs), .div(let lhs, let rhs), .mul(let lhs, let rhs), .and(let lhs, let rhs), .or(let lhs, let rhs):
            try lhs.walk(config: config)
            try rhs.walk(config: config)
            
        case let .between(e, lower, upper):
            try e.walk(config: config)
            try lower.walk(config: config)
            try upper.walk(config: config)
            
        case .valuein(let e, let exprs):
            try e.walk(config: config)
            try exprs.forEach { (e) in
                try e.walk(config: config)
            }
        case .call(_, let exprs):
            try exprs.forEach { (e) in
                try e.walk(config: config)
            }
            
        case .exists(let a):
            if config.type.descendIntoAlgebras {
                try a.walk(config: config.findingExpressionsInAlgebras)
            }
        }
    }
}
