//
//  Expression.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 7/31/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation

public enum Aggregation {
    case countAll
    case count(Expression, Bool)
    case sum(Expression, Bool)
    case avg(Expression, Bool)
    case min(Expression)
    case max(Expression)
    case sample(Expression)
    case groupConcat(Expression, String, Bool)
}

extension Aggregation: Equatable {
    public static func == (lhs: Aggregation, rhs: Aggregation) -> Bool {
        switch (lhs, rhs) {
        case (.countAll, .countAll):
            return true
        case (.count(let l), .count(let r)) where l == r:
            return true
        case (.sum(let l), .sum(let r)) where l == r:
            return true
        case (.avg(let l), .avg(let r)) where l == r:
            return true
        case (.min(let l), .min(let r)) where l == r:
            return true
        case (.max(let l), .max(let r)) where l == r:
            return true
        case (.sample(let l), .sample(let r)) where l == r:
            return true
        case (.groupConcat(let l), .groupConcat(let r)) where l == r:
            return true
        default:
            return false
        }
    }
}

extension Aggregation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .countAll:
            return "COUNT(*)"
        case .count(let expr, false):
            return "COUNT(\(expr.description))"
        case .count(let expr, true):
            return "COUNT(DISTINCT \(expr.description))"
        case .sum(let expr, false):
            return "SUM(\(expr.description))"
        case .sum(let expr, true):
            return "SUM(DISTINCT \(expr.description))"
        case .avg(let expr, false):
            return "AVG(\(expr.description))"
        case .avg(let expr, true):
            return "AVG(DISTINCT \(expr.description))"
        case .min(let expr):
            return "MIN(\(expr.description))"
        case .max(let expr):
            return "MAX(\(expr.description))"
        case .sample(let expr):
            return "SAMPLE(\(expr.description))"
        case .groupConcat(let expr, let sep, let distinct):
            let e = distinct ? "DISTINCT \(expr.description)" : expr.description
            if sep == " " {
                return "GROUP_CONCAT(\(e))"
            } else {
                return "GROUP_CONCAT(\(e); SEPARATOR=\"\(sep)\")"
            }
        }
    }
}

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable:next type_body_length
public indirect enum Expression: CustomStringConvertible {
    case node(Node)
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
    case bound(Expression)
    case boolCast(Expression)
    case intCast(Expression)
    case floatCast(Expression)
    case doubleCast(Expression)
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
    
    public var hasAggregation: Bool {
        switch self {
        case .aggregate(_):
            return true
        case .node(_), .exists(_):
            return false
        case .not(let expr), .isiri(let expr), .isblank(let expr), .isliteral(let expr), .isnumeric(let expr), .lang(let expr), .datatype(let expr), .bound(let expr), .boolCast(let expr), .intCast(let expr), .floatCast(let expr), .doubleCast(let expr), .neg(let expr):
            return expr.hasAggregation
        case .eq(let lhs, let rhs), .ne(let lhs, let rhs), .lt(let lhs, let rhs), .le(let lhs, let rhs), .gt(let lhs, let rhs), .ge(let lhs, let rhs), .add(let lhs, let rhs), .sub(let lhs, let rhs), .div(let lhs, let rhs), .mul(let lhs, let rhs), .and(let lhs, let rhs), .or(let lhs, let rhs), .langmatches(let lhs, let rhs):
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
        case .valuein(let expr, let exprs):
            return .valuein(expr.removeAggregations(counter, mapping: &mapping), exprs.map { $0.removeAggregations(counter, mapping: &mapping) })
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
        case .call(let iri, let exprs):
            let strings = exprs.map { $0.description }
            return "<\(iri)>(\(strings.joined(separator: ",")))"
        case .lang(let expr):
            return "LANG(\(expr))"
        case .langmatches(let expr, let m):
            return "LANGMATCHES(\(expr), \"\(m)\")"
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

extension Expression: Equatable {
    public static func == (lhs: Expression, rhs: Expression) -> Bool {
        switch (lhs, rhs) {
        case (.aggregate(let l), .aggregate(let r)) where l == r:
            return true
        case (.node(let l), .node(let r)) where l == r:
            return true
        case (.eq(let ll, let lr), .eq(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.ne(let ll, let lr), .ne(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.gt(let ll, let lr), .gt(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.lt(let ll, let lr), .lt(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.ge(let ll, let lr), .ge(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.le(let ll, let lr), .le(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.add(let ll, let lr), .add(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.sub(let ll, let lr), .sub(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.mul(let ll, let lr), .mul(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.div(let ll, let lr), .div(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.between(let l), .between(let r)) where l == r:
            return true
        case (.neg(let l), .neg(let r)) where l == r:
            return true
        case (.and(let ll, let lr), .and(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.or(let ll, let lr), .or(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.not(let l), .not(let r)) where l == r:
            return true
        case (.isiri(let l), .isiri(let r)) where l == r:
            return true
        case (.isblank(let l), .isblank(let r)) where l == r:
            return true
        case (.isliteral(let l), .isliteral(let r)) where l == r:
            return true
        case (.isnumeric(let l), .isnumeric(let r)) where l == r:
            return true
        case (.boolCast(let l), .boolCast(let r)) where l == r:
            return true
        case (.intCast(let l), .intCast(let r)) where l == r:
            return true
        case (.floatCast(let l), .floatCast(let r)) where l == r:
            return true
        case (.doubleCast(let l), .doubleCast(let r)) where l == r:
            return true
        case (.call(let l, let largs), .call(let r, let rargs)) where l == r && largs == rargs:
            return true
        case (.lang(let l), .lang(let r)) where l == r:
            return true
        case (.datatype(let l), .datatype(let r)) where l == r:
            return true
        case (.bound(let l), .bound(let r)) where l == r:
            return true
        case (.exists(let l), .exists(let r)) where l == r:
            return true
        default:
            return false
        }
    }
}

public extension Expression {
    func replace(_ map: (Expression) throws -> Expression?) throws -> Expression {
        if let e = try map(self) {
            return e
        } else {
            switch self {
            case .node(_):
                return self
            case .aggregate(let a):
                return try .aggregate(a.replace(map))
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
            case .call(let iri, let exprs):
                return try .call(iri, exprs.map { try $0.replace(map) })
            case .lang(let expr):
                return try .lang(expr.replace(map))
            case .langmatches(let expr, let m):
                return try .langmatches(expr.replace(map), m)
            case .datatype(let expr):
                return try .datatype(expr.replace(map))
            case .bound(let expr):
                return try .bound(expr.replace(map))
            case .valuein(let expr, let exprs):
                return try .valuein(expr.replace(map), exprs.map { try $0.replace(map) })
            case .not(let expr):
                return try .not(expr.replace(map))
            case .exists(_):
                return self
            }
        }
    }
}

public extension Aggregation {
    func replace(_ map: (Expression) throws -> Expression?) throws -> Aggregation {
        switch self {
        case .countAll:
            return self
        case .count(let expr, let distinct):
            return try .count(expr.replace(map), distinct)
        case .sum(let expr, let distinct):
            return try .sum(expr.replace(map), distinct)
        case .avg(let expr, let distinct):
            return try .avg(expr.replace(map), distinct)
        case .min(let expr):
            return try .min(expr.replace(map))
        case .max(let expr):
            return try .max(expr.replace(map))
        case .sample(let expr):
            return try .sample(expr.replace(map))
        case .groupConcat(let expr, let sep, let distinct):
            return try .groupConcat(expr.replace(map), sep, distinct)
        }
    }
}
