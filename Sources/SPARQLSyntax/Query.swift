import Foundation

public enum SelectProjection : Equatable {
    case star
    case variables([String])
}

public enum QueryForm : Equatable {
    case select(SelectProjection)
    case ask
    case construct([TriplePattern])
    case describe([Node])
}

public struct Dataset : Equatable {
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

public struct Query : Equatable {
    public var base: String?
    public var form: QueryForm
    public var algebra: Algebra
    public var dataset: Dataset?
    
    public init(form: QueryForm, algebra: Algebra, dataset: Dataset? = nil, base: String? = nil) throws {
        self.base = base
        self.form = form
        self.algebra = algebra
        self.dataset = dataset
        
        if case .select(.variables(let vars)) = form {
            let vset = Set(vars)
            if vars.count != vset.count {
                throw SPARQLParsingError.parsingError("Cannot project variables more than once in a SELECT query")
            }
        }
    }
}


public extension Query {
    public func serialize(depth: Int=0) -> String {
        let indent = String(repeating: " ", count: (depth*2))
        let algebra = self.algebra
        var d = "\(indent)Query\n"
        if let dataset = self.dataset {
            d += "\(indent)  Dataset\n"
            for g in dataset.defaultGraphs {
                d += "\(indent)    Default graph: \(g)\n"
            }
            for g in dataset.namedGraphs {
                d += "\(indent)    Named graph: \(g)\n"
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
            d += "\(indent)  Select { \(v.joined(separator: ", ")) }\n"
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
