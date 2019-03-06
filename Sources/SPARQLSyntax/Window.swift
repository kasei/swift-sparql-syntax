//
//  Window.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 3/6/19.
//

import Foundation

public enum WindowFunction : String, Codable {
    case rowNumber
    case rank
    
    public var variables: Set<String> {
        switch self {
        case .rowNumber, .rank:
            return Set()
        }
    }
}

extension WindowFunction: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rowNumber:
            return "ROW_NUMBER()"
        case .rank:
            return "RANK()"
        }
    }
}

public extension WindowFunction {
    func replace(_ map: [String:Term]) throws -> WindowFunction {
        switch self {
        case .rank:
            return self
        case .rowNumber:
            return self
        }
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> WindowFunction {
        switch self {
        case .rank:
            return self
        case .rowNumber:
            return self
        }
    }
    
    func rewrite(_ map: (Expression) throws -> RewriteStatus<Expression>) throws -> WindowFunction {
        switch self {
        case .rank:
            return self
        case .rowNumber:
            return self
        }
    }
}

public struct WindowFrame: Hashable, Codable {
    enum FrameBound: Hashable {
        case current
        case unbound
        case preceding(Expression)
        case following(Expression)
    }
    enum FrameType: Hashable {
        case rows
        case range
    }
    var type: FrameType
    var from: FrameBound
    var to: FrameBound
}

extension WindowFrame.FrameBound : Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case expression
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "current":
            self = .current
        case "unbound":
            self = .unbound
        case "preceding":
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .preceding(expr)
        case "following":
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .following(expr)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected window frame bound type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .current:
            try container.encode("current", forKey: .type)
        case .unbound:
            try container.encode("unbound", forKey: .type)
        case .preceding(let expr):
            try container.encode("preceding", forKey: .type)
            try container.encode(expr, forKey: .expression)
        case .following(let expr):
            try container.encode("following", forKey: .type)
            try container.encode(expr, forKey: .expression)
        }
    }
}

extension WindowFrame.FrameType : Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "rows":
            self = .rows
        case "range":
            self = .range
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected window frame type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .rows:
            try container.encode("rows", forKey: .type)
        case .range:
            try container.encode("range", forKey: .type)
        }
    }
}


public struct WindowApplication: Hashable, Codable {
    public var windowFunction: WindowFunction
    public var comparators: [Algebra.SortComparator]
    public var partition: [Expression]
    public var frame: WindowFrame
    public var variables: Set<String> {
        return windowFunction.variables
    }
}

public extension WindowApplication {
    func replace(_ map: [String:Term]) throws -> WindowApplication {
        let cmps = try self.comparators.map { (cmp) in
            try Algebra.SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
        }
        let partition = try self.partition.map { (e) in
            try e.replace(map)
        }
        print("*** TODO: rewrite the frame expressions")
        return WindowApplication(
            windowFunction: windowFunction,
            comparators: cmps,
            partition: partition,
            frame: frame) // TODO: rewrite the frame expressions
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> WindowApplication {
        let cmps = try self.comparators.map { (cmp) in
            try Algebra.SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
        }
        let partition = try self.partition.map { (e) in
            try e.replace(map)
        }
        print("*** TODO: rewrite the frame expressions")
        return WindowApplication(
            windowFunction: windowFunction,
            comparators: cmps,
            partition: partition,
            frame: frame) // TODO: rewrite the frame expressions
    }
    
    func rewrite(_ map: (Expression) throws -> RewriteStatus<Expression>) throws -> WindowApplication {
        fatalError("TODO: implement WindowApplication.rewrite(_:) -> RewriteStatus<Expression>")
    }
}

extension WindowFrame: CustomStringConvertible {
    public var description: String {
//        case current
//        case unbound
//        case preceding(Expression)
//        case following(Expression)
        return "\(type) BETWEEN \(from) TO \(to)"
    }
}

extension WindowApplication: CustomStringConvertible {
    public var description: String {
        let f = self.windowFunction.description
        let frame = self.frame
        let order = self.comparators
        let groups = self.partition

        var parts = [String]()
        switch (frame.from, frame.to) {
        case (.unbound, .unbound):
            return "\(f) OVER (PARTITION BY \(groups) ORDER BY \(order))"
        default:
            parts.append(frame.description)
        }
        
        if !groups.isEmpty {
            parts.append("PARTITION BY \(groups)")
        }
        
        if !order.isEmpty {
            parts.append("ORDER BY \(order)")
        }

        return "\(f) OVER (\(parts.joined(separator: " ")))"
    }
}

