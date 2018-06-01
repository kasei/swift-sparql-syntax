import Foundation

public enum SelectProjection : Equatable {
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

public enum QueryForm : Equatable {
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

public struct Dataset : Codable, Equatable {
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

public struct Query : Codable, Equatable {
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
                    throw SPARQLSyntaxError.parsingError("Cannot project non-grouped variable in aggregation query")
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


public extension Query {
    public func serialize(depth: Int=0) -> String {
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
            d += algebra.serialize(depth: depth+6)
            d += "\(indent)    Template\n"
            for t in triples {
                d += "\(indent)      \(t)\n"
            }
        case .describe(let nodes):
            let expressions = nodes.map { "\($0)" }
            d += "\(indent)  Describe { \(expressions.joined(separator: ", ")) }\n"
            d += algebra.serialize(depth: depth+4)
        case .ask:
            d += "\(indent)  Ask\n"
            d += algebra.serialize(depth: depth+4)
        case .select(.star):
            d += "\(indent)  Select { * }\n"
            d += algebra.serialize(depth: depth+4)
        case .select(.variables(let v)):
            d += "\(indent)  Select { \(v.map { "?\($0)" }.joined(separator: ", ")) }\n"
            d += algebra.serialize(depth: depth+4)
        }
        return d
    }
}

public extension Query {
    public var inscope: Set<String> {
        return self.algebra.inscope
    }
    
    public var projectedVariables: [String] {
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
    
    public func rewrite(_ map: (Algebra) throws -> RewriteStatus<Algebra>) throws -> Query {
        let algebra = try self.algebra.rewrite(map)
        return try Query(form: self.form, algebra: algebra, dataset: self.dataset, base: self.base)
    }
}
