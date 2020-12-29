//
//  File.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 4/28/18.
//

import Foundation

public protocol TermPattern {
    associatedtype GroundType: Sequence
    static var groundKeyPaths: [KeyPath<GroundType, Term>] { get }
    static var groundKeyNames: [String] { get }
    var isGround: Bool { get }
    var ground: GroundType? { get }
    func matches(_ statement: GroundType) -> Bool
    func makeIterator() -> IndexingIterator<[Node]>
    var bindingAllVariables: Self { get }
}

extension TermPattern {
    public var variables: Set<String> {
        let vars = self.makeIterator().compactMap { (n) -> String? in
            switch n {
            case .variable(let name, binding: _):
                return name
            default:
                return nil
            }
        }
        return Set(vars)
    }

    public var isGround: Bool {
        for n in makeIterator() {
            if case .variable = n {
                return false
            }
        }
        return true
    }
    
    public func bindings(for statement: GroundType) -> [String:Term]? {
        guard self.matches(statement) else { return nil }
        var d = [String: Term]()
        let patternType = type(of: self)
        for (node, path) in zip(self.makeIterator(), patternType.groundKeyPaths) {
            switch node {
            case .variable(let name, true):
                let term = statement[keyPath: path]
                d[name] = term
            default:
                break
            }
        }
        return d
    }
}

public struct TriplePattern: Hashable, Equatable, Codable, TermPattern, CustomStringConvertible {
    public var subject: Node
    public var predicate: Node
    public var object: Node
    public typealias GroundType = Triple
    public static var groundKeyPaths: [KeyPath<GroundType, Term>] = [\Triple.subject, \Triple.predicate, \Triple.object]
    public static var groundKeyNames = ["subject", "predicate", "object"]
    
    public init(subject: Node, predicate: Node, object: Node) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }
    
    public var description: String {
        return "\(subject) \(predicate) \(object) ."
    }
    
    public func bind(_ variable: String, to replacement: Node) -> TriplePattern {
        let subject = self.subject.bind(variable, to: replacement)
        let predicate = self.predicate.bind(variable, to: replacement)
        let object = self.object.bind(variable, to: replacement)
        return TriplePattern(subject: subject, predicate: predicate, object: object)
    }
    
    public var bindingAllVariables: TriplePattern {
        let nodes = self.map { (n) -> Node in
            switch n {
            case .variable(let name, binding: false):
                return .variable(name, binding: true)
            default:
                return n
            }
        }
        let s = nodes[0]
        let p = nodes[1]
        let o = nodes[2]
        return TriplePattern(subject: s, predicate: p, object: o)
    }

    public static var all: TriplePattern {
        return TriplePattern(
            subject: .variable("subject", binding: true),
            predicate: .variable("predicate", binding: true),
            object: .variable("object", binding: true)
        )
    }
}

extension TriplePattern {
    public subscript(_ position: Triple.Position) -> Node {
        switch position {
        case .subject:
            return self.subject
        case .predicate:
            return self.predicate
        case .object:
            return self.object
        }
    }
}

extension TriplePattern: Sequence {
    public func makeIterator() -> IndexingIterator<[Node]> {
        return [subject, predicate, object].makeIterator()
    }
}

extension TriplePattern {
    public var ground: GroundType? {
        guard case let .bound(s) = subject, case let .bound(p) = predicate, case let .bound(o) = object else { return nil }
        return Triple(subject: s, predicate: p, object: o)
    }

    public func replace(_ map: (Node) throws -> Node?) throws -> TriplePattern {
        var nodes = [subject, predicate, object]
        for (i, node) in nodes.enumerated() {
            if let n = try map(node) {
                nodes[i] = n
            }
        }
        return TriplePattern(subject: nodes[0], predicate: nodes[1], object: nodes[2])
    }
    
    public func matches(_ triple: Triple) -> Bool {
        var matched = [String:Term]()
        for (node, term) in zip(self, triple) {
            switch node {
            case .variable(let name, binding: true):
                if let t = matched[name] {
                    if t != term {
                        return false
                    }
                } else {
                    matched[name] = term
                }
            case .bound(let t) where t != term:
                return false
            default:
                continue
            }
        }
        return true
    }
}

public struct QuadPattern: Hashable, Equatable, Codable, TermPattern, CustomStringConvertible {
    public var subject: Node
    public var predicate: Node
    public var object: Node
    public var graph: Node
    public typealias GroundType = Quad
    public static var keyPaths: [WritableKeyPath<QuadPattern, Node>] = [\.subject, \.predicate, \.object, \.graph]
    public static var groundKeyPaths: [KeyPath<GroundType, Term>] = [\Quad.subject, \Quad.predicate, \Quad.object, \Quad.graph]
    public static var groundKeyNames = ["subject", "predicate", "object", "graph"]

    public init(triplePattern tp: TriplePattern, graph: Node) {
        self.subject = tp.subject
        self.predicate = tp.predicate
        self.object = tp.object
        self.graph = graph
    }
    
    public init(subject: Node, predicate: Node, object: Node, graph: Node) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.graph = graph
    }
    public var description: String {
        return "\(subject) \(predicate) \(object) \(graph)."
    }
    
    public func bind(_ variable: String, to replacement: Node) -> QuadPattern {
        let subject = self.subject.bind(variable, to: replacement)
        let predicate = self.predicate.bind(variable, to: replacement)
        let object = self.object.bind(variable, to: replacement)
        let graph = self.graph.bind(variable, to: replacement)
        return QuadPattern(subject: subject, predicate: predicate, object: object, graph: graph)
    }

    public func expand(_ values: [String:Term]) -> QuadPattern {
        var qp = self
        for p in QuadPattern.keyPaths {
            let n = self[keyPath: p]
            if case .variable(let name, _) = n {
                if let term = values[name] {
                    qp[keyPath: p] = .bound(term)
                }
            }
        }
        return qp
    }

    public var bindingAllVariables: QuadPattern {
        let nodes = self.map { (n) -> Node in
            switch n {
            case .variable(let name, binding: false):
                return .variable(name, binding: true)
            default:
                return n
            }
        }
        let s = nodes[0]
        let p = nodes[1]
        let o = nodes[2]
        let g = nodes[3]
        return QuadPattern(subject: s, predicate: p, object: o, graph: g)
    }

    public static var all: QuadPattern {
        return QuadPattern(
            subject: .variable("subject", binding: true),
            predicate: .variable("predicate", binding: true),
            object: .variable("object", binding: true),
            graph: .variable("graph", binding: true)
        )
    }
}

extension QuadPattern {
    public subscript(_ position: Quad.Position) -> Node {
        switch position {
        case .subject:
            return self.subject
        case .predicate:
            return self.predicate
        case .object:
            return self.object
        case .graph:
            return self.graph
        }
    }
}

extension QuadPattern: Sequence {
    public func makeIterator() -> IndexingIterator<[Node]> {
        return [subject, predicate, object, graph].makeIterator()
    }
}

extension QuadPattern {
    public var ground: GroundType? {
        guard case let .bound(s) = subject, case let .bound(p) = predicate, case let .bound(o) = object, case let .bound(g) = graph else { return nil }
        return Quad(subject: s, predicate: p, object: o, graph: g)
    }
    
    public func replace(_ map: (Node) throws -> Node?) throws -> QuadPattern {
        var nodes = [subject, predicate, object, graph]
        for (i, node) in nodes.enumerated() {
            if let n = try map(node) {
                nodes[i] = n
            }
        }
        return QuadPattern(subject: nodes[0], predicate: nodes[1], object: nodes[2], graph: nodes[3])
    }
    
    public func matches(_ quad: Quad) -> Bool {
        var matched = [String:Term]()
        for (node, term) in zip(self, quad) {
            switch node {
            case .variable(let name, binding: true):
                if let t = matched[name] {
                    if t != term {
                        return false
                    }
                } else {
                    matched[name] = term
                }
            case .bound(let t) where t != term:
                return false
            default:
                continue
            }
        }
        return true
    }
}

public indirect enum EmbeddedTriplePattern: Hashable, Equatable, CustomStringConvertible {
    case node(Node)
    case embeddedTriple(Pattern)

    public struct Pattern: Hashable, Codable {
        public var subject: EmbeddedTriplePattern
        public var predicate: Node
        public var object: EmbeddedTriplePattern
        
        public init(subject: EmbeddedTriplePattern, predicate: Node, object: EmbeddedTriplePattern) {
            self.subject = subject
            self.predicate = predicate
            self.object = object
        }

        public var description: String {
            return "\(subject) \(predicate) \(object) ."
        }
    }

    public var description: String {
        switch self {
        case .node(let n):
            return n.description
        case .embeddedTriple(let p):
            return p.description
        }
    }

    public init(subject: EmbeddedTriplePattern, predicate: Node, object: EmbeddedTriplePattern) {
        let et = Pattern(subject: subject, predicate: predicate, object: object)
        self = .embeddedTriple(et)
    }
}

extension EmbeddedTriplePattern: Codable {
    private enum CodingKeys: String, CodingKey {
        case node
        case triple
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "node":
            let n = try container.decode(Node.self, forKey: .node)
            self = .node(n)
        case "embed":
            let t = try container.decode(EmbeddedTriplePattern.Pattern.self, forKey: .triple)
            self = .embeddedTriple(t)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected EmbeddedTriplePattern type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .node(n):
            try container.encode("node", forKey: .type)
            try container.encode(n, forKey: .node)
        case .embeddedTriple(let t):
            try container.encode("embed", forKey: .type)
            try container.encode(t, forKey: .triple)
        }
    }
}

public extension EmbeddedTriplePattern {
    func replace(_ map: (Node) throws -> Node?) throws -> EmbeddedTriplePattern {
        switch self {
        case .node(let node):
            if let n = try map(node) {
                return .node(n)
            } else {
                return self
            }
        case .embeddedTriple(let t):
            let subject = try t.subject.replace(map)
            let predicate: Node
            if let n = try map(t.predicate) {
                predicate = n
            } else {
                predicate = t.predicate
            }
            let object = try t.object.replace(map)
            let et = Pattern(subject: subject, predicate: predicate, object: object)
            return .embeddedTriple(et)
        }
    }

    func bind(_ variable: String, to replacement: Node) -> EmbeddedTriplePattern {
        switch self {
        case .node(let n):
            return .node(n.bind(variable, to: replacement))
        case .embeddedTriple(let t):
            return .embeddedTriple(t.bind(variable, to: replacement))
        }
    }
}

public extension EmbeddedTriplePattern.Pattern {
    func replace(_ map: (Node) throws -> Node?) throws -> EmbeddedTriplePattern.Pattern {
        let subject = try self.subject.replace(map)
        let predicate: Node
        if let n = try map(self.predicate) {
            predicate = n
        } else {
            predicate = self.predicate
        }
        let object = try self.object.replace(map)
        return EmbeddedTriplePattern.Pattern(subject: subject, predicate: predicate, object: object)
    }

    func bind(_ variable: String, to replacement: Node) -> EmbeddedTriplePattern.Pattern {
        let s = self.subject.bind(variable, to: replacement)
        let p = self.predicate.bind(variable, to: replacement)
        let o = self.object.bind(variable, to: replacement)
        return EmbeddedTriplePattern.Pattern(subject: s, predicate: p, object: o)
    }
}
