//
//  Aggregation.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 6/3/18.
//

import Foundation

public enum Aggregation : Equatable, Hashable {
    case countAll
    case count(Expression, Bool)
    case sum(Expression, Bool)
    case avg(Expression, Bool)
    case min(Expression)
    case max(Expression)
    case sample(Expression)
    case groupConcat(Expression, String, Bool)
    
    public var variables: Set<String> {
        switch self {
        case .countAll:
            return Set()
        case .count(let e, _),
             .sum(let e, _),
             .avg(let e, _),
             .min(let e),
             .max(let e),
             .sample(let e),
             .groupConcat(let e, _, _):
            return e.variables
        }
    }
}

extension Aggregation: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case expression
        case distinct
        case string
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "countAll":
            self = .countAll
        case "count":
            let expr = try container.decode(Expression.self, forKey: .expression)
            let distinct = try container.decode(Bool.self, forKey: .distinct)
            self = .count(expr, distinct)
        case "sum":
            let expr = try container.decode(Expression.self, forKey: .expression)
            let distinct = try container.decode(Bool.self, forKey: .distinct)
            self = .sum(expr, distinct)
        case "avg":
            let expr = try container.decode(Expression.self, forKey: .expression)
            let distinct = try container.decode(Bool.self, forKey: .distinct)
            self = .avg(expr, distinct)
        case "min":
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .min(expr)
        case "max":
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .max(expr)
        case "sample":
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .sample(expr)
        case "groupConcat":
            let expr = try container.decode(Expression.self, forKey: .expression)
            let distinct = try container.decode(Bool.self, forKey: .distinct)
            let sep = try container.decode(String.self, forKey: .string)
            self = .groupConcat(expr, sep, distinct)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected aggregation type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .countAll:
            try container.encode("countAll", forKey: .type)
        case let .count(expr, distinct):
            try container.encode("count", forKey: .type)
            try container.encode(expr, forKey: .expression)
            try container.encode(distinct, forKey: .distinct)
        case let .sum(expr, distinct):
            try container.encode("sum", forKey: .type)
            try container.encode(expr, forKey: .expression)
            try container.encode(distinct, forKey: .distinct)
        case let .avg(expr, distinct):
            try container.encode("avg", forKey: .type)
            try container.encode(expr, forKey: .expression)
            try container.encode(distinct, forKey: .distinct)
        case let .min(expr):
            try container.encode("min", forKey: .type)
            try container.encode(expr, forKey: .expression)
        case let .max(expr):
            try container.encode("max", forKey: .type)
            try container.encode(expr, forKey: .expression)
        case let .sample(expr):
            try container.encode("sample", forKey: .type)
            try container.encode(expr, forKey: .expression)
        case let .groupConcat(expr, sep, distinct):
            try container.encode("groupConcat", forKey: .type)
            try container.encode(expr, forKey: .expression)
            try container.encode(distinct, forKey: .distinct)
            try container.encode(sep, forKey: .string)
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

public extension Aggregation {
    func replace(_ map: [String:Term]) throws -> Aggregation {
        let nodes = map.mapValues { Node.bound($0) }
        return try self.replace(nodes)
    }
    
    func replace(_ map: [String:Node]) throws -> Aggregation {
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
    
    func rewrite(_ map: (Expression) throws -> RewriteStatus<Expression>) throws -> Aggregation {
        switch self {
        case .countAll:
            return self
        case .count(let expr, let distinct):
            return try .count(expr.rewrite(map), distinct)
        case .sum(let expr, let distinct):
            return try .sum(expr.rewrite(map), distinct)
        case .avg(let expr, let distinct):
            return try .avg(expr.rewrite(map), distinct)
        case .min(let expr):
            return try .min(expr.rewrite(map))
        case .max(let expr):
            return try .max(expr.rewrite(map))
        case .sample(let expr):
            return try .sample(expr.rewrite(map))
        case .groupConcat(let expr, let sep, let distinct):
            return try .groupConcat(expr.rewrite(map), sep, distinct)
        }
    }
}
