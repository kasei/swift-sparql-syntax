import Foundation

public enum SelectProjection : Equatable, Hashable {
    case star
    case variables([String])
}

extension SelectProjection: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case variables
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "variables":
            let vars = try container.decode([String].self, forKey: .variables)
            self = .variables(vars)
        default:
            self = .star
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .variables(vars):
            try container.encode("variables", forKey: .type)
            try container.encode(vars, forKey: .variables)
        case .star:
            try container.encode("star", forKey: .type)
        }
    }
}

public enum QueryForm : Equatable, Hashable {
    case select(SelectProjection)
    case ask
    case construct([TriplePattern])
    case describe([Node])
}

extension QueryForm: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case projection
        case patterns
        case nodes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "select":
            let p = try container.decode(SelectProjection.self, forKey: .projection)
            self = .select(p)
        case "ask":
            self = .ask
        case "construct":
            let tps = try container.decode([TriplePattern].self, forKey: .patterns)
            self = .construct(tps)
        case "describe":
            let nodes = try container.decode([Node].self, forKey: .nodes)
            self = .describe(nodes)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected query form type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .select(p):
            try container.encode("select", forKey: .type)
            try container.encode(p, forKey: .projection)
        case .ask:
            try container.encode("ask", forKey: .type)
        case let .construct(tps):
            try container.encode("construct", forKey: .type)
            try container.encode(tps, forKey: .patterns)
        case let .describe(nodes):
            try container.encode("describe", forKey: .type)
            try container.encode(nodes, forKey: .nodes)
        }
    }
}

public struct Dataset : Codable, Equatable, Hashable {
    public var defaultGraphs: [Term]
    public var namedGraphs: [Term]
    
    public init(defaultGraphs: [Term]? = nil, namedGraphs: [Term]? = nil) {
        self.defaultGraphs = defaultGraphs ?? []
        self.namedGraphs = namedGraphs ?? []
    }
    
    public var isEmpty : Bool {
        return defaultGraphs.count == 0 && namedGraphs.count == 0
    }
}

public extension Dataset {
    func serialize(depth: Int=0) -> String {
        let indent = String(repeating: " ", count: (depth*2))
        var d = "\(indent)Dataset\n"
        for g in self.defaultGraphs {
            d += "\(indent)  Default graph: \(g)\n"
        }
        for g in self.namedGraphs {
            d += "\(indent)  Named graph: \(g)\n"
        }
        return d
    }
}

public struct Query : Codable, Hashable, Equatable {
    public var base: String?
    public var form: QueryForm
    public var algebra: Algebra
    public var dataset: Dataset?
    
    public init(form: QueryForm, algebra: Algebra, dataset: Dataset? = nil, base: String? = nil) throws {
        self.base = base
        self.form = form
        self.algebra = algebra
        self.dataset = dataset

        switch form {
        case .select(.star):
            if algebra.isAggregation {
                throw SPARQLSyntaxError.parsingError("Aggregation queries cannot use a `SELECT *`")
            }
        case .select(.variables(let vars)):
            if algebra.isAggregation {
                var a = algebra
                if case .project(let b, _) = a {
                    a = b
                }
                if !(Set(vars).isSubset(of: a.projectableVariables)) {
                    throw SPARQLSyntaxError.parsingError("Cannot project non-grouped variable(s) \(vars) in aggregation query. Projectable variables are: \(a.projectableVariables)")
                }
            }

            let vset = Set(vars)
            if vars.count != vset.count {
                throw SPARQLSyntaxError.parsingError("Cannot project variables more than once in a SELECT query")
            }
        default:
            break
        }
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
    case modify([TriplePattern], [QuadPattern], [TriplePattern], [QuadPattern], Dataset, Algebra)
}

public struct Update : Hashable, Equatable {
    public var base: String?
    public var operations: [UpdateOperation]
    public var dataset: Dataset?
    
    public init(operations: [UpdateOperation], dataset: Dataset? = nil, base: String? = nil) throws {
        self.base = base
        self.operations = operations
        self.dataset = dataset
    }
}


public extension Update {
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
            case let .modify(dt, dq, it, iq, ds, algebra):
                d += "\(indent)  Modify:\n"
                d += ds.serialize(depth: depth+2)
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
            default:
                fatalError("Unexpected UpdateForm: \(op)")
            }
        }
        return d
    }
}

public extension Query {
    func serialize(depth: Int=0) -> String {
        let indent = String(repeating: " ", count: (depth*2))
        let algebra = self.algebra
        var d = "\(indent)Query\n"
        if let dataset = self.dataset {
            if !dataset.isEmpty {
                d += "\(indent)  Dataset\n"
                for g in dataset.defaultGraphs {
                    d += "\(indent)    Default graph: \(g)\n"
                }
                for g in dataset.namedGraphs {
                    d += "\(indent)    Named graph: \(g)\n"
                }
            }
        }
        switch self.form {
        case .construct(let triples):
            d += "\(indent)  Construct\n"
            d += "\(indent)    Algebra\n"
            d += algebra.serialize(depth: depth+3)
            d += "\(indent)    Template\n"
            for t in triples {
                d += "\(indent)      \(t)\n"
            }
        case .describe(let nodes):
            let expressions = nodes.map { "\($0)" }
            d += "\(indent)  Describe { \(expressions.joined(separator: ", ")) }\n"
            d += algebra.serialize(depth: depth+2)
        case .ask:
            d += "\(indent)  Ask\n"
            d += algebra.serialize(depth: depth+2)
        case .select(.star):
            d += "\(indent)  Select { * }\n"
            d += algebra.serialize(depth: depth+2)
        case .select(.variables(let v)):
            d += "\(indent)  Select { \(v.map { "?\($0)" }.joined(separator: ", ")) }\n"
            d += algebra.serialize(depth: depth+2)
        }
        return d
    }
}

public extension Query {
    var inscope: Set<String> {
        return self.algebra.inscope
    }
    
    var necessarilyBound: Set<String> {
        switch self.form {
        case .select(.variables(let v)):
            return self.algebra.necessarilyBound.intersection(v)
        case .select(.star):
            return self.algebra.necessarilyBound
        case .ask, .construct(_), .describe(_):
            return Set()
        }
    }
    
    var projectedVariables: [String] {
        switch self.form {
        case .select(.variables(let v)):
            return v
        case .select(.star):
            return self.inscope.sorted()
        case .ask, .construct(_), .describe(_):
            return []
        }
    }
}


public extension Query {
    func replace(_ map: [String:Term]) throws -> Query {
        let nodes = map.mapValues { Node.bound($0) }
        return try self.replace(nodes)
    }
    
    func replace(_ map: [String:Node]) throws -> Query {
        let algebra = try self.algebra.replace(map)
        return try Query(form: self.form, algebra: algebra, dataset: self.dataset, base: self.base)
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> Query {
        let algebra = try self.algebra.replace(map)
        return try Query(form: self.form, algebra: algebra, dataset: self.dataset, base: self.base)
    }
    
    func replace(_ map: (Algebra) throws -> Algebra?) throws -> Query {
        let algebra = try self.algebra.replace(map)
        return try Query(form: self.form, algebra: algebra, dataset: self.dataset, base: self.base)
    }
    
    func rewrite(_ map: (Algebra) throws -> RewriteStatus<Algebra>) throws -> Query {
        let algebra = try self.algebra.rewrite(map)
        return try Query(form: self.form, algebra: algebra, dataset: self.dataset, base: self.base)
    }
}

enum SPARQLResultError: Error {
    case compatabilityError(String)
}

public struct SPARQLResultSolution<T: Hashable & Comparable>: Hashable, CustomStringConvertible {
    public typealias TermType = T
    public private(set) var bindings: [String: T]
    
    public init(bindings: [String: T]) {
        self.bindings = bindings
    }
    
    public var keys: [String] { return Array(self.bindings.keys) }
    
    public func join(_ rhs: Self<T>) -> Self<T>? {
        let lvars = Set(bindings.keys)
        let rvars = Set(rhs.bindings.keys)
        let shared = lvars.intersection(rvars)
        for key in shared {
            guard bindings[key] == rhs.bindings[key] else { return nil }
        }
        var b = bindings
        for (k, v) in rhs.bindings {
            b[k] = v
        }
        
        let result = Self(bindings: b)
        //        print("]]]] \(self) |><| \(rhs) ==> \(result)")
        return result
    }
    
    public func projected(variables: Set<String>) -> Self<T> {
        var bindings = [String:TermType]()
        for name in variables {
            if let term = self[name] {
                bindings[name] = term
            }
        }
        return Self(bindings: bindings)
    }

    public subscript(key: Node) -> TermType? {
        get {
            switch key {
            case .variable(let name, _):
                return self.bindings[name]
            default:
                return nil
            }
        }

        set(value) {
            if case .variable(let name, _) = key {
                self.bindings[name] = value
            }
        }
    }

    public subscript(key: String) -> TermType? {
        get {
            return bindings[key]
        }

        set(value) {
            bindings[key] = value
        }
    }

    public mutating func extend(variable: String, value: TermType) throws {
        if let existing = self.bindings[variable] {
            if existing != value {
                throw SPARQLResultError.compatabilityError("Cannot extend solution mapping due to existing incompatible term value")
            }
        }
        self.bindings[variable] = value
    }

    public func extended(variable: String, value: TermType) -> Self<T>? {
        var b = bindings
        if let existing = b[variable] {
            if existing != value {
                print("*** cannot extend result with new term: (\(variable) <- \(value); \(self)")
                return nil
            }
        }
        b[variable] = value
        return Self(bindings: b)
    }

    public var description: String {
        let pairs = bindings.sorted { $0.0 < $1.0 }.map { "\($0): \($1)" }.joined(separator: ", ")
        return "Result[\(pairs)]"
    }

    public func description(orderedBy variables: [String]) -> String {
        let order = Dictionary(uniqueKeysWithValues: variables.enumerated().map { ($0.element, $0.offset) })
        let pairs = bindings.sorted { order[$0.0, default: Int.max] < order[$1.0, default: Int.max] }.map { "\($0): \($1)" }.joined(separator: ", ")
        return "Result[\(pairs)]"
    }

    public func makeIterator() -> DictionaryIterator<String, TermType> {
        let i = bindings.makeIterator()
        return i
    }

    public func removing(variables: Set<String>) -> Self<T> {
        var bindings = [String: T]()
        for (k, v) in self.bindings {
            if !variables.contains(k) {
                bindings[k] = v
            }
        }
        return Self(bindings: bindings)
    }
}
