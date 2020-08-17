//
//  Update.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 8/17/20.
//

import Foundation

public struct Update : Hashable, Equatable {
    public var base: String?
    public var operations: [UpdateOperation]
    public var dataset: Dataset?
    
    public init(operations: [UpdateOperation], dataset: Dataset? = nil, base: String? = nil) throws {
        self.base = base
        self.operations = operations
        self.dataset = dataset
    }

    func guardBlankNodeReuse() throws {
        var seenLabels = Set<String>()
        for op in self.operations {
            let i = seenLabels.intersection(op.blankNodeLabels)
            if !i.isEmpty {
                throw SPARQLSyntaxError.parsingError("Blank node labels cannot be used across update operations: \(i.joined(separator: ", "))")
            }
            seenLabels.formUnion(op.blankNodeLabels)
        }
    }
}

public extension Update {
    private func description(of graph: UpdateOperation.GraphOrDefault) -> String {
        switch graph {
        case .defaultGraph:
            return "default graph"
        case .namedGraph(let g):
            return g.description
        }
    }
    
    func serialize(depth: Int=0) -> String {
        let indent = String(repeating: " ", count: (depth*2))
        var d = "\(indent)Update\n"
        if let dataset = self.dataset {
            d += dataset.serialize(depth: depth+1)
        }
        for op in self.operations {
            switch op {
            case let .load(data, graph, silent):
                let s = silent ? " (SILENT)" : ""
                if let g = graph {
                    d += "\(indent)  Load \(data) INTO \(g)\(s)\n"
                } else {
                    d += "\(indent)  Load \(data)\(s)\n"
                }
            case let .clear(graph, silent):
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Clear \(graph)\(s)\n"
            case let .drop(graph, silent):
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Drop \(graph)\(s)\n"
            case let .create(graph, silent):
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Create \(graph)\(s)\n"
            case let .insertData(triples, quads):
                d += "\(indent)  Insert Data:\n"
                for t in triples {
                    d += "\(indent)    \(t) .\n"
                }
                for q in quads {
                    d += "\(indent)    \(q) .\n"
                }
            case let .deleteData(triples, quads):
                d += "\(indent)  Delete Data:\n"
                for t in triples {
                    d += "\(indent)    \(t)\n"
                }
                for q in quads {
                    d += "\(indent)    \(q)\n"
                }
            case let .modify(dt, dq, it, iq, ds, algebra):
                d += "\(indent)  Modify:\n"
                if let ds = ds {
                    d += ds.serialize(depth: depth+2)
                }
                let delete = dt.count + dq.count
                if delete > 0 {
                    d += "\(indent)    Delete:\n"
                    for t in dt {
                        d += "\(indent)      \(t)\n"
                    }
                    for q in dq {
                        d += "\(indent)      \(q)\n"
                    }
                }
                
                let insert = it.count + iq.count
                if insert > 0 {
                    d += "\(indent)    Insert:\n"
                    for t in it {
                        d += "\(indent)      \(t)\n"
                    }
                    for q in iq {
                        d += "\(indent)      \(q)\n"
                    }
                }
                d += "\(indent)    Where:\n"
                d += algebra.serialize(depth: depth+3)
            case let .add(src, dst, silent):
                let from = description(of: src)
                let to = description(of: dst)
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Add \(from) to \(to)\(s)\n"
            case let .move(src, dst, silent):
                let from = description(of: src)
                let to = description(of: dst)
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Move \(from) to \(to)\(s)\n"
            case let .copy(src, dst, silent):
                let from = description(of: src)
                let to = description(of: dst)
                let s = silent ? " (SILENT)" : ""
                d += "\(indent)  Copy \(from) to \(to)\(s)\n"
            }
        }
        return d
    }
}

public enum UpdateOperation : Hashable {
    public enum GraphReference: Hashable {
        case defaultGraph
        case allGraphs
        case namedGraphs
        case namedGraph(Term)
    }
    public enum GraphOrDefault: Hashable {
        case defaultGraph
        case namedGraph(Term)
    }
    case load(Term, Term?, Bool)
    case clear(GraphReference, Bool)
    case drop(GraphReference, Bool)
    case create(Term, Bool)
    case add(GraphOrDefault, GraphOrDefault, Bool)
    case move(GraphOrDefault, GraphOrDefault, Bool)
    case copy(GraphOrDefault, GraphOrDefault, Bool)
    case insertData([Triple], [Quad])
    case deleteData([Triple], [Quad])
    case modify([TriplePattern], [QuadPattern], [TriplePattern], [QuadPattern], Dataset?, Algebra)

    var blankNodeLabels: Set<String> {
        switch self {
        case .load, .clear, .drop, .create, .add, .move, .copy:
            return []
        case let .insertData(triples, quads), let .deleteData(triples, quads):
            let t : [Algebra] = triples.map { .triple(TriplePattern(triple: $0)) }
            let q : [Algebra] = quads.map { .quad(QuadPattern(quad: $0)) }
            var labels = Set<String>()
            for a in t {
                labels.formUnion(a.blankNodeLabels)
            }
            for a in q {
                labels.formUnion(a.blankNodeLabels)
            }
            return labels
        case let .modify(dt, dq, it, iq, _, _):
            var labels = Set<String>()
            for (triples, quads) in [(dt, dq), (it, iq)] {
                let t : [Algebra] = triples.map { .triple($0) }
                let q : [Algebra] = quads.map { .quad($0) }
                for a in t {
                    labels.formUnion(a.blankNodeLabels)
                }
                for a in q {
                    labels.formUnion(a.blankNodeLabels)
                }
            }
            return labels
        }
    }
}

