//
//  File.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 4/28/18.
//

import Foundation

protocol TermPattern {
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
    public var isGround: Bool {
        for n in makeIterator() {
            if case .variable(_) = n {
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
    static var groundKeyNames = ["subject", "predicate", "object"]
    
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
    static var groundKeyNames = ["subject", "predicate", "object", "graph"]

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
    
    func bind(_ variable: String, to replacement: Node) -> QuadPattern {
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
