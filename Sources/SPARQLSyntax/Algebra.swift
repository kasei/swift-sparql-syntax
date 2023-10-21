import Foundation

public enum RewriteStatus<A> {
    case keep
    case rewriteChildren(A)
    case rewrite(A)
}

public struct WalkType {
    public static let defaultType = WalkType(descendIntoAlgebras: true, descendIntoSubqueries: false, descendIntoExpressions: false)
    var descendIntoAlgebras: Bool
    var descendIntoSubqueries: Bool
    var descendIntoExpressions: Bool
    public init(descendIntoAlgebras: Bool, descendIntoSubqueries: Bool, descendIntoExpressions: Bool) {
        self.descendIntoAlgebras = descendIntoAlgebras
        self.descendIntoSubqueries = descendIntoSubqueries
        self.descendIntoExpressions = descendIntoExpressions
    }
}

typealias WalkHandlerCallback<C> = (C) throws -> ()
public struct WalkConfig {
    var type: WalkType
    var algebraHandler: WalkHandlerCallback<Algebra>?
    var expressionHandler: WalkHandlerCallback<Expression>?
    
    func handle(_ a : Algebra) throws {
        if let h = algebraHandler {
            try h(a)
        }
    }
    
    func handle(_ e : Expression) throws {
        if let h = expressionHandler {
            try h(e)
        }
    }
    
    var findingAlgebrasInExpressions: WalkConfig {
        var newConfig = self
        let newExpressionHandler : WalkHandlerCallback<Expression> = { (e) in
            try handle(e)
            
            switch e {
            case .exists(let a):
                try a.walk(config: self)
            default:
                break
            }
        }
        newConfig.algebraHandler = nil
        newConfig.expressionHandler = newExpressionHandler
        return newConfig
    }
    
    var findingExpressionsInAlgebras: WalkConfig {
        var newConfig = self
        let newAlgebraHandler : WalkHandlerCallback<Algebra> = { (a) in
            try handle(a)
            
            switch a {
            case .leftOuterJoin(_, _, let e), .filter(_, let e), .extend(_, let e, _):
                try e.walk(config: self)
            case .order(_, let cmps):
                try cmps.forEach {
                    try $0.expression.walk(config: self)
                }
            case .aggregate(_, let exprs, let mapping):
                try exprs.forEach {
                    try $0.walk(config: self)
                }
                
                mapping.forEach { (mapping) in
                    print("TODO: walk into aggregation expressions")
                }
            case .window(_, let mapping):
                mapping.forEach { (mapping) in
                    print("TODO: walk into window expressions")
                }
            default:
                return
            }
        }
        newConfig.algebraHandler = newAlgebraHandler
        newConfig.expressionHandler = nil
        return newConfig
    }
}


public indirect enum Algebra : Hashable {
    public struct SortComparator : Hashable, Equatable, Codable, CustomStringConvertible {
        public var ascending: Bool
        public var expression: Expression
        
        public init(ascending: Bool, expression: Expression) {
            self.ascending = ascending
            self.expression = expression
        }
        
        public func sparqlTokens() throws -> AnySequence<SPARQLToken> {
            var tokens = [SPARQLToken]()
            var exprTokens : [SPARQLToken] = []
            
            var addParens : Bool = expression.needsSurroundingParentheses
            if case .node(.bound(_)) = expression {
                addParens = true
            }
            
            if addParens {
                exprTokens.append(.lparen)
                exprTokens.append(contentsOf: try expression.sparqlTokens())
                exprTokens.append(.rparen)
            } else {
                exprTokens.append(contentsOf: try expression.sparqlTokens())
            }
            
            if ascending {
                tokens.append(contentsOf: exprTokens)
            } else {
                tokens.append(.keyword("DESC"))
                tokens.append(.lparen)
                tokens.append(contentsOf: exprTokens)
                tokens.append(.rparen)
            }
            return AnySequence(tokens)
        }

        public var description: String {
            let direction = ascending ? "ASC" : "DESC"
            return "\(direction)(\(expression))"
        }
    }
    
    public struct AggregationMapping: Hashable, Equatable, Codable, CustomStringConvertible {
        public var aggregation: Aggregation
        public var variableName: String
        
        public init(aggregation: Aggregation, variableName: String) {
            self.aggregation = aggregation
            self.variableName = variableName
        }
        
        public var description: String {
            return "Agg[?\(variableName) ← \(aggregation)]"
        }
    }
    
    public struct WindowFunctionMapping: Hashable, Equatable, Codable {
        public var windowApplication: WindowApplication
        public var variableName: String

        public init(windowApplication: WindowApplication, variableName: String) {
            self.windowApplication = windowApplication
            self.variableName = variableName
        }
        
        public var description: String {
            return "?\(variableName) ← \(windowApplication)"
        }
    }
    
    case unionIdentity
    case joinIdentity
    case table([Node], [[Term?]])
    case quad(QuadPattern)
    case triple(TriplePattern)
    case bgp([TriplePattern])
    case innerJoin(Algebra, Algebra)
    case leftOuterJoin(Algebra, Algebra, Expression)
    case filter(Algebra, Expression)
    case union(Algebra, Algebra)
    case namedGraph(Algebra, Node)
    case extend(Algebra, Expression, String)
    case minus(Algebra, Algebra)
    case project(Algebra, Set<String>)
    case distinct(Algebra)
    case reduced(Algebra)
    case service(URL, Algebra, Bool)
    case slice(Algebra, Int?, Int?)
    case order(Algebra, [SortComparator])
    case path(Node, PropertyPath, Node)
    case aggregate(Algebra, [Expression], Set<AggregationMapping>)
    case window(Algebra, [WindowFunctionMapping])
    case subquery(Query)
}

extension Algebra : Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case nodes
        case terms
        case triplePattern
        case quadPattern
        case triplePatterns
        case lhs
        case rhs
        case expression
        case name
        case node
        case silent
        case variables
        case limit
        case offset
        case path
        case subject
        case object
        case expressions
        case groups
        case aggregations
        case windowFunctions
        case comparators
        case query
        case url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "unionIdentity":
            self = .unionIdentity
        case "joinIdentity":
            self = .joinIdentity
        case "table":
            let nodes = try container.decode([Node].self, forKey: .nodes)
            let terms = try container.decode([[Term?]].self, forKey: .terms)
            self = .table(nodes, terms)
        case "quadPattern":
            let qp = try container.decode(QuadPattern.self, forKey: .quadPattern)
            self = .quad(qp)
        case "triplePattern":
            let tp = try container.decode(TriplePattern.self, forKey: .triplePattern)
            self = .triple(tp)
        case "bgp":
            let triples = try container.decode([TriplePattern].self, forKey: .triplePatterns)
            self = .bgp(triples)
        case "innerJoin":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .rhs)
            self = .innerJoin(lhs, rhs)
        case "leftOuterJoin":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .rhs)
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .leftOuterJoin(lhs, rhs, expr)
        case "filter":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .filter(lhs, expr)
        case "union":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .rhs)
            self = .union(lhs, rhs)
        case "namedGraph":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let graph = try container.decode(Node.self, forKey: .node)
            self = .namedGraph(lhs, graph)
        case "extend":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let expr = try container.decode(Expression.self, forKey: .expression)
            let name = try container.decode(String.self, forKey: .name)
            self = .extend(lhs, expr, name)
        case "minus":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .rhs)
            self = .minus(lhs, rhs)
        case "project":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let vars = try container.decode(Set<String>.self, forKey: .variables)
            self = .project(lhs, vars)
        case "distinct":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            self = .distinct(lhs)
        case "reduced":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            self = .reduced(lhs)
        case "service":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let endpoint = try container.decode(URL.self, forKey: .url)
            let silent = try container.decode(Bool.self, forKey: .silent)
            self = .service(endpoint, lhs, silent)
        case "slice":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let offset = try container.decode(Int?.self, forKey: .offset)
            let limit = try container.decode(Int?.self, forKey: .limit)
            self = .slice(lhs, offset, limit)
        case "order":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let cmps = try container.decode([SortComparator].self, forKey: .comparators)
            self = .order(lhs, cmps)
        case "propertyPath":
            let s = try container.decode(Node.self, forKey: .subject)
            let o = try container.decode(Node.self, forKey: .object)
            let pp = try container.decode(PropertyPath.self, forKey: .path)
            self = .path(s, pp, o)
        case "aggregate":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let groups = try container.decode([Expression].self, forKey: .groups)
            let aggs = try container.decode(Set<AggregationMapping>.self, forKey: .aggregations)
            self = .aggregate(lhs, groups, aggs)
        case "window":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let windows = try container.decode([WindowFunctionMapping].self, forKey: .windowFunctions)
            self = .window(lhs, windows)
        case "query":
            let q = try container.decode(Query.self, forKey: .query)
            self = .subquery(q)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected algebra type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unionIdentity:
            try container.encode("unionIdentity", forKey: .type)
        case .joinIdentity:
            try container.encode("joinIdentity", forKey: .type)
        case let .table(nodes, terms):
            try container.encode("table", forKey: .type)
            try container.encode(nodes, forKey: .nodes)
            try container.encode(terms, forKey: .terms)
        case .quad(let qp):
            try container.encode("quadPattern", forKey: .type)
            try container.encode(qp, forKey: .quadPattern)
        case .triple(let tp):
            try container.encode("triplePattern", forKey: .type)
            try container.encode(tp, forKey: .triplePattern)
        case let .bgp(tps):
            try container.encode("bgp", forKey: .type)
            try container.encode(tps, forKey: .triplePatterns)
        case let .innerJoin(lhs, rhs):
            try container.encode("innerJoin", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .leftOuterJoin(lhs, rhs, expr):
            try container.encode("leftOuterJoin", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
            try container.encode(expr, forKey: .expression)
        case let .filter(lhs, expr):
            try container.encode("filter", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(expr, forKey: .expression)
        case let .union(lhs, rhs):
            try container.encode("union", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .namedGraph(lhs, node):
            try container.encode("namedGraph", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(node, forKey: .node)
        case let .extend(lhs, expr, name):
            try container.encode("extend", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(expr, forKey: .expression)
            try container.encode(name, forKey: .name)
        case let .minus(lhs, rhs):
            try container.encode("minus", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .project(lhs, v):
            try container.encode("project", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(v, forKey: .variables)
        case let .distinct(lhs):
            try container.encode("distinct", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .reduced(lhs):
            try container.encode("reduced", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
        case let .service(endpoint, lhs, silent):
            try container.encode("service", forKey: .type)
            try container.encode(endpoint, forKey: .url)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(silent, forKey: .silent)
        case let .slice(lhs, offset, limit):
            try container.encode("slice", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(offset, forKey: .offset)
            try container.encode(limit, forKey: .limit)
        case let .order(lhs, cmps):
            try container.encode("order", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(cmps, forKey: .comparators)
        case let .path(s, pp, o):
            try container.encode("propertyPath", forKey: .type)
            try container.encode(s, forKey: .subject)
            try container.encode(pp, forKey: .path)
            try container.encode(o, forKey: .object)
        case let .aggregate(lhs, groups, aggs):
            try container.encode("aggregate", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(groups, forKey: .groups)
            try container.encode(aggs, forKey: .aggregations)
        case let .window(lhs, windows):
            try container.encode("window", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(windows, forKey: .windowFunctions)
        case .subquery(let q):
            try container.encode("query", forKey: .type)
            try container.encode(q, forKey: .query)
        }
    }
}

public extension Algebra {
    // swiftlint:disable:next cyclomatic_complexity
    func serialize(depth: Int=0) -> String {
        let indent = String(repeating: " ", count: (depth*2))
        
        switch self {
        case .unionIdentity:
            return "\(indent)Empty\n"
        case .joinIdentity:
            return "\(indent)Join Identity\n"
        case .quad(let q):
            return "\(indent)Quad(\(q))\n"
        case .triple(let t):
            return "\(indent)Triple(\(t))\n"
        case .bgp(let triples):
            var d = "\(indent)BGP\n"
            for t in triples {
                d += "\(indent)  \(t)\n"
            }
            return d
        case .innerJoin(let lhs, let rhs):
            var d = "\(indent)Join\n"
            d += lhs.serialize(depth: depth+1)
            d += rhs.serialize(depth: depth+1)
            return d
        case .leftOuterJoin(let lhs, let rhs, let expr):
            var d = "\(indent)LeftJoin (\(expr))\n"
            for c in [lhs, rhs] {
                d += c.serialize(depth: depth+1)
            }
            return d
        case .union(let lhs, let rhs):
            var d = "\(indent)Union\n"
            for c in [lhs, rhs] {
                d += c.serialize(depth: depth+1)
            }
            return d
        case .namedGraph(let child, let graph):
            var d = "\(indent)NamedGraph \(graph)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .service(let endpoint, let child, let silent):
            let modifier = silent ? " (Silent)" : ""
            var d = "\(indent)Service\(modifier) \(endpoint)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .extend(let child, let expr, let name):
            var d = "\(indent)Extend ?\(name) ← \(expr)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .project(let child, let variables):
            var d = "\(indent)Project { \(variables.map { "?\($0)" }.joined(separator: ", ")) }\n"
            d += child.serialize(depth: depth+1)
            return d
        case .distinct(let child):
            var d = "\(indent)Distinct\n"
            d += child.serialize(depth: depth+1)
            return d
        case .reduced(let child):
            var d = "\(indent)Reduced\n"
            d += child.serialize(depth: depth+1)
            return d
        case .slice(let child, nil, .some(let limit)), .slice(let child, .some(0), .some(let limit)):
            var d = "\(indent)Limit \(limit)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .slice(let child, .some(let offset), nil):
            var d = "\(indent)Offset \(offset)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .slice(let child, let offset, let limit):
            var d = "\(indent)Slice offset=\(String(describing: offset)) limit=\(String(describing: limit))\n"
            d += child.serialize(depth: depth+1)
            return d
        case .order(let child, let orders):
            let expressions = orders.map { $0.ascending ? "\($0.expression)" : "DESC(\($0.expression))" }
            var d = "\(indent)OrderBy { \(expressions.joined(separator: ", ")) }\n"
            d += child.serialize(depth: depth+1)
            return d
        case .filter(let child, let expr):
            var d = "\(indent)Filter \(expr)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .minus(let lhs, let rhs):
            var d = "\(indent)Minus\n"
            d += lhs.serialize(depth: depth+1)
            d += rhs.serialize(depth: depth+1)
            return d
        case .path(let subject, let pp, let object):
            return "\(indent)Path(\(subject), \(pp), \(object))\n"
        case .aggregate(let child, let groups, let aggs):
            var d = "\(indent)Aggregate \(aggs) over groups \(groups)\n"
            d += child.serialize(depth: depth+1)
            return d
        case .window(let child, let funcs):
            let windows = funcs.map { $0.description }
            var d = "\(indent)Window { \(windows.joined(separator: ", ")) }\n"
            d += child.serialize(depth: depth+1)
            return d
        case .table(let nodes, let results):
            let vars = nodes.map { $0.description }
            var d = "\(indent)Table { \(vars.joined(separator: ", ")) }\n"
            for result in results {
                d += "\(indent)  \(result)\n"
            }
            return d
        case .subquery(let a):
            var d = "\(indent)Sub-select\n"
            d += a.serialize(depth: depth+1)
            return d
        }
    }
}

public extension Algebra {
    private func inscopeUnion(children: [Algebra]) -> Set<String> {
        if children.count == 0 {
            return Set()
        }
        var vars = children.map { $0.inscope }
        while vars.count > 1 {
            let l = vars.popLast()!
            let r = vars.popLast()!
            vars.append(l.union(r))
        }
        return vars.popLast()!
    }
    
    var inscope: Set<String> {
        var variables = Set<String>()
        switch self {
        case .joinIdentity, .unionIdentity:
            return Set()
        case .project(_, let vars):
            return Set(vars)
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs):
            return inscopeUnion(children: [lhs, rhs])
        case .triple(let t):
            for node in [t.subject, t.predicate, t.object] {
                if case .variable(let name, true) = node {
                    variables.insert(name)
                }
            }
            return variables
        case .quad(let q):
            for node in [q.subject, q.predicate, q.object, q.graph] {
                if case .variable(let name, true) = node {
                    variables.insert(name)
                }
            }
            return variables
        case .bgp(let triples):
            if triples.count == 0 {
                return Set()
            }
            var variables = Set<String>()
            for t in triples {
                for node in [t.subject, t.predicate, t.object] {
                    if case .variable(let name, true) = node {
                        variables.insert(name)
                    }
                }
            }
            return variables
        case .leftOuterJoin(let lhs, let rhs, _):
            return inscopeUnion(children: [lhs, rhs])
        case .extend(let child, _, let v):
            var variables = child.inscope
            variables.insert(v)
            return variables
        case .subquery(let q):
            return q.inscope
        case .filter(let child, _), .minus(let child, _), .distinct(let child), .reduced(let child), .slice(let child, _, _), .namedGraph(let child, .bound(_)), .order(let child, _), .service(_, let child, _):
            return child.inscope
        case .namedGraph(let child, .variable(let v, let bind)):
            var variables = child.inscope
            if bind {
                variables.insert(v)
            }
            return variables
        case .path(let subject, _, let object):
            var variables = Set<String>()
            for node in [subject, object] {
                if case .variable(let name, true) = node {
                    variables.insert(name)
                }
            }
            return variables
        case .aggregate(_, let groups, let aggs):
            for g in groups {
                if case .node(.variable(let name, true)) = g {
                    variables.insert(name)
                }
            }
            for a in aggs {
                variables.insert(a.variableName)
            }
            return variables
        case .window(let child, let funcs):
            var variables = child.inscope
            for w in funcs {
                variables.insert(w.variableName)
            }
            return variables
        case .table(let nodes, _):
            for node in nodes {
                if case .variable(let name, _) = node {
                    variables.insert(name)
                }
            }
            return variables
        }
    }
    
    var necessarilyBound: Set<String> {
        switch self {
        case .joinIdentity, .unionIdentity, .table(_, _):
            return Set()
        case let .project(child, vars):
            return child.necessarilyBound.intersection(vars)
        case .innerJoin(let lhs, let rhs):
            return lhs.necessarilyBound.union(rhs.necessarilyBound)
        case .union(let lhs, let rhs):
            return lhs.necessarilyBound.intersection(rhs.necessarilyBound)
        case .triple(_), .quad(_), .bgp(_), .path(_, _, _):
            return self.inscope
        case .extend(let child, _, let v):
            return child.necessarilyBound.union([v])
        case .subquery(let q):
            return q.necessarilyBound
        case .filter(let child, _), .minus(let child, _), .distinct(let child), .reduced(let child), .slice(let child, _, _), .namedGraph(let child, .bound(_)), .order(let child, _), .service(_, let child, _), .leftOuterJoin(let child, _, _):
            return child.necessarilyBound
        case .namedGraph(let child, .variable(let v, let bind)):
            var variables = child.necessarilyBound
            if bind {
                variables.insert(v)
            }
            return variables
        case let .aggregate(child, _, aggs):
            return child.necessarilyBound.union(aggs.map { $0.variableName })
        case .window(let child, let funcs):
            return child.necessarilyBound.union(funcs.map { $0.variableName })
        }
    }
    
    var projectableVariables : Set<String> {
        switch self {
        case let .aggregate(_, groups, aggs):
            var vars = Set(aggs.map { $0.variableName })
            for g in groups {
                if case .node(.variable(let v, _)) = g {
                    vars.insert(v)
                }
            }
            return vars
            
        case .project(_, let v):
            return v

        case .extend(let child, _, let v):
            return Set([v]).union(child.projectableVariables)
            
        default:
            return self.inscope
        }
    }
    
    internal var variableExtensions: [String:Expression] {
        switch self {
        case .joinIdentity, .unionIdentity, .triple, .quad, .bgp, .path, .window, .table, .subquery, .minus(_, _), .union(_, _), .aggregate, .leftOuterJoin, .service, .filter(_, _), .namedGraph(_, _):
            return [:]
            
        case .project(let child, _), .distinct(let child), .reduced(let child), .slice(let child, _, _), .order(let child, _):
            return child.variableExtensions
            
        case .innerJoin(let lhs, let rhs):
            let le = lhs.variableExtensions
            let re = rhs.variableExtensions
            return le.merging(re) { (l,r) in l }
            
        case let .extend(child, expr, name):
            var d = child.variableExtensions
            d[name] = expr
            return d
        }
    }
    
    var aggregation: Algebra? {
        switch self {
        case .joinIdentity, .unionIdentity, .triple, .quad, .bgp, .path, .window, .table, .subquery:
            return nil
            
        case .project(let child, _), .minus(let child, _), .distinct(let child), .reduced(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _):
            return child.aggregation
            
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs), .leftOuterJoin(let lhs, let rhs, _):
            return lhs.aggregation ?? rhs.aggregation
            
        case .aggregate:
            return self
        case .extend(let child, _, _), .filter(let child, _):
            return child.aggregation
        }
    }
    
    var isAggregation: Bool {
        if let _ = aggregation {
            return true
        } else {
            return false
        }
    }

    var window: Algebra? {
        switch self {
        case .joinIdentity, .unionIdentity, .triple, .quad, .bgp, .path, .aggregate, .table, .subquery:
            return nil
            
        case .project(let child, _), .minus(let child, _), .distinct(let child), .reduced(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _):
            return child.window
            
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs), .leftOuterJoin(let lhs, let rhs, _):
            return lhs.window ?? rhs.window
            
        case .window:
            return self
            
        case .extend(let child, _, _), .filter(let child, _):
            return child.window
        }
    }
    
    var isWindow: Bool {
        if let _ = window {
            return true
        } else {
            return false
        }
    }
}

public extension Algebra {
    func renameAggregateAndWindowVariables(from: String, to: String) -> Algebra? {
        switch self {
        case let .aggregate(child, groups, aggs):
            var renamed = false
            var rewritten = Set<Algebra.AggregationMapping>()
            for a in aggs {
                if a.variableName == from {
                    renamed = true
                    rewritten.insert(AggregationMapping(aggregation: a.aggregation, variableName: to))
                } else {
                    rewritten.insert(a)
                }
            }
            if renamed {
                return .aggregate(child, groups, rewritten)
            } else {
                return nil
            }
        case let .window(child, windows):
            var renamed = false
            var rewritten = [Algebra.WindowFunctionMapping]()
            for w in windows {
                if w.variableName == from {
                    renamed = true
                    rewritten.append(WindowFunctionMapping(windowApplication: w.windowApplication, variableName: to))
                } else {
                    rewritten.append(w)
                }
            }
            if renamed {
                return .window(child, rewritten)
            } else {
                return nil
            }
        default:
            return self
        }
    }
    
    func replace(_ map: [String:Term]) throws -> Algebra {
        let nodes = map.mapValues { Node.bound($0) }
        return try self.replace(nodes)
    }
    
    func replace(_ map: [String:Node]) throws -> Algebra {
        let a = try self.replace({ (e) -> Expression? in
            return try e.replace(map)
        })
        
        return try a.replace({ (a) -> Algebra? in
            switch a {
            case .triple(let tp):
                let r = try tp.replace({ (n) -> Node? in
                    switch n {
                    case .variable(let name, _):
                        if let t = map[name] {
                            return t
                        } else {
                            return n
                        }
                    default:
                        return n
                    }
                })
                return .triple(r)
            case .quad(let qp):
                let r = try qp.replace { (n) -> Node? in
                    switch n {
                    case .variable(let name, _):
                        if let t = map[name] {
                            return t
                        } else {
                            return n
                        }
                    default:
                        return n
                    }
                }
                return .quad(r)
            case .bgp(let tps):
                let r = try tps.map { (tp) -> TriplePattern in
                    return try tp.replace { (n) -> Node? in
                        switch n {
                        case .variable(let name, _):
                            if let t = map[name] {
                                return t
                            } else {
                                return n
                            }
                        default:
                            return n
                        }
                    }
                }
                return .bgp(r)
            case let .path(s, pp, o):
                var subj = s
                var obj = o
                if case .variable(let name, _) = s {
                    if let t = map[name] {
                        subj = t
                    }
                }
                if case .variable(let name, _) = o {
                    if let t = map[name] {
                        obj = t
                    }
                }
                return .path(subj, pp, obj)
            case let .project(a, vars):
                return try .project(a.replace(map), vars)
            case let .namedGraph(a, g):
                var graph = g
                if case .variable(let name, _) = g {
                    if let t = map[name] {
                        graph = t
                    }
                }
                return try .namedGraph(a.replace(map), graph)
            case .subquery(let q):
                return try .subquery(q.replace(map))
            case .unionIdentity, .joinIdentity:
                return self
            case .distinct(let a):
                return try .distinct(a.replace(map))
            case .reduced(let a):
                return try .reduced(a.replace(map))
            case .minus(let a, let b):
                return try .minus(a.replace(map), b.replace(map))
            case .union(let a, let b):
                return try .union(a.replace(map), b.replace(map))
            case .innerJoin(let a, let b):
                return try .innerJoin(a.replace(map), b.replace(map))
            case .slice(let a, let offset, let limit):
                return try .slice(a.replace(map), offset, limit)
            case .service(let endpoint, let a, let silent):
                return try .service(endpoint, a.replace(map), silent)
            case .filter(let a, let expr):
                return try .filter(a.replace(map), expr.replace(map))
            case .leftOuterJoin(let a, let b, let expr):
                return try .leftOuterJoin(a.replace(map), b.replace(map), expr.replace(map))
            case .extend(let a, let expr, let v):
                return try .extend(a.replace(map), expr.replace(map), v)
            case .order(let a, let cmps):
                return try .order(a.replace(map), cmps.map { cmp in
                    try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
                })
            case .aggregate(let a, let exprs, let aggs):
                let exprs = try exprs.map { (expr) in
                    return try expr.replace(map)
                }
                let aggs = try aggs.map { (data) -> AggregationMapping in
                    return try AggregationMapping(aggregation: data.aggregation.replace(map), variableName: data.variableName)
                }
                return try .aggregate(a.replace(map), exprs, Set(aggs))
            case .window(let a, let funcs):
                let funcs = try funcs.map { data -> WindowFunctionMapping in
                    let e = try data.windowApplication.comparators.map { cmp in
                        try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
                    }
                    let partition = try data.windowApplication.partition.map { e in
                        try e.replace(map)
                    }
                    let application = WindowApplication(
                        windowFunction: data.windowApplication.windowFunction,
                        comparators: e,
                        partition: partition,
                        frame: data.windowApplication.frame
                    )
                    return WindowFunctionMapping(
                        windowApplication: application,
                        variableName: data.variableName
                    )
                }
                return try .window(a.replace(map), funcs)
            case let .table(nodes, rows):
                let keepNodes = nodes.enumerated().compactMap { (data) -> (Int, Node)? in
                    let n = data.element
                    switch n {
                    case .variable(let name, _):
                        if let _ = map[name] {
                            return nil
                        } else {
                            return data
                        }
                    default:
                        return data
                    }
                }
                
                if keepNodes.count < nodes.count {
                    let _nodes = keepNodes.map { $0.1 }
                    let indexes = keepNodes.map { $0.0 }
                    let _rows = rows.map { (terms) -> [Term?] in
                        return indexes.map { terms[$0] }
                    }
                    return .table(_nodes, _rows)
                } else {
                    return .table(nodes, rows)
                }
            }
        })
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> Algebra {
        switch self {
        case .subquery(let q):
            return try .subquery(q.replace(map))
        case .unionIdentity, .joinIdentity, .triple, .quad, .path, .bgp, .table:
            return self
        case .distinct(let a):
            return try .distinct(a.replace(map))
        case .reduced(let a):
            return try .reduced(a.replace(map))
        case .project(let a, let p):
            return try .project(a.replace(map), p)
        case .minus(let a, let b):
            return try .minus(a.replace(map), b.replace(map))
        case .union(let a, let b):
            return try .union(a.replace(map), b.replace(map))
        case .innerJoin(let a, let b):
            return try .innerJoin(a.replace(map), b.replace(map))
        case .namedGraph(let a, let node):
            return try .namedGraph(a.replace(map), node)
        case .slice(let a, let offset, let limit):
            return try .slice(a.replace(map), offset, limit)
        case .service(let endpoint, let a, let silent):
            return try .service(endpoint, a.replace(map), silent)
        case .filter(let a, let expr):
            return try .filter(a.replace(map), expr.replace(map))
        case .leftOuterJoin(let a, let b, let expr):
            return try .leftOuterJoin(a.replace(map), b.replace(map), expr.replace(map))
        case .extend(let a, let expr, let v):
            return try .extend(a.replace(map), expr.replace(map), v)
        case .order(let a, let cmps):
            return try .order(a.replace(map), cmps.map { cmp in
                try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
            })
        case .aggregate(let a, let exprs, let aggs):
            // case aggregate(Algebra, [Expression], [(Aggregation, String)])
            let exprs = try exprs.map { (expr) in
                return try expr.replace(map)
            }
            let aggs = try aggs.map { data in
                return try AggregationMapping(aggregation: data.aggregation.replace(map), variableName: data.variableName)
            }
            return try .aggregate(a.replace(map), exprs, Set(aggs))
        case .window(let a, let funcs):
            //     case window(Algebra, [Expression], [WindowFunctionMapping])
            let funcs = try funcs.map { data -> WindowFunctionMapping in
                let e = try data.windowApplication.comparators.map { cmp in
                    try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
                }
                let partition = try data.windowApplication.partition.map { e in
                    try e.replace(map)
                }
                let application = WindowApplication(
                    windowFunction: data.windowApplication.windowFunction,
                    comparators: e,
                    partition: partition,
                    frame: data.windowApplication.frame
                )
                return WindowFunctionMapping(
                    windowApplication: application,
                    variableName: data.variableName
                )
            }
            return try .window(a.replace(map), funcs)
        }
    }
    
    func replace(_ map: (Algebra) throws -> Algebra?) throws -> Algebra {
        return try self.rewrite { (a) -> RewriteStatus<Algebra> in
            if let r = try map(a) {
                return .rewrite(r)
            } else {
                return .rewriteChildren(a)
            }
        }
    }

    func walk(_ handler:  @escaping (Algebra) throws -> ()) throws {
        let config = WalkConfig(type: .defaultType, algebraHandler: handler)
        try walk(config: config)
    }
    
    func walk(config: WalkConfig) throws {
        try config.handle(self)
        
        switch self {
        case .unionIdentity, .joinIdentity, .triple, .quad, .path, .bgp, .table:
            return
        case .subquery(let q):
            if config.type.descendIntoSubqueries {
                try q.algebra.walk(config: config)
            }
        case .distinct(let a):
            try a.walk(config: config)
        case .reduced(let a):
            try a.walk(config: config)
        case .project(let a, _):
            try a.walk(config: config)
        case .order(let a, let cmps):
            try cmps.forEach {
                try $0.expression.walk(config: config)
            }
            try a.walk(config: config)
        case .minus(let a, let b):
            try a.walk(config: config)
            try b.walk(config: config)
        case .union(let a, let b):
            try a.walk(config: config)
            try b.walk(config: config)
        case .innerJoin(let a, let b):
            try a.walk(config: config)
            try b.walk(config: config)
        case .leftOuterJoin(let a, let b, let e):
            if config.type.descendIntoExpressions {
                try e.walk(config: config.findingAlgebrasInExpressions)
            }
            try a.walk(config: config)
            try b.walk(config: config)
        case .extend(let a, let e, _):
            if config.type.descendIntoExpressions {
                try e.walk(config: config.findingAlgebrasInExpressions)
            }
            try a.walk(config: config)
        case .filter(let a, let e):
            if config.type.descendIntoExpressions {
                try e.walk(config: config.findingAlgebrasInExpressions)
            }
            try a.walk(config: config)
        case .namedGraph(let a, _):
            try a.walk(config: config)
        case .slice(let a, _, _):
            try a.walk(config: config)
        case .service(_, let a, _):
            try a.walk(config: config)
        case .aggregate(let a, let groups, let aggs):
            try a.walk(config: config)
            if config.type.descendIntoExpressions {
                try groups.forEach {
                    try $0.walk(config: config.findingAlgebrasInExpressions)
                }
                for agg in aggs {
                    if let e = agg.aggregation.expression {
                        try e.walk(config: config.findingAlgebrasInExpressions)
                    }
                }
            }
        case .window(let a, let windows):
            try a.walk(config: config)
            if config.type.descendIntoExpressions {
                for w in windows {
                    try w.windowApplication.comparators.forEach {
                        try $0.expression.walk(config: config.findingAlgebrasInExpressions)
                    }
                    if let exprs = w.windowApplication.windowFunction.expressions {
                        try exprs.forEach {
                            try $0.walk(config: config.findingAlgebrasInExpressions)
                        }
                    }
                }
            }
        }
    }
    
    func rewrite(allowReprocessing: Bool = true, _ map: (Algebra) throws -> RewriteStatus<Algebra>) throws -> Algebra {
        let (a, _) = try _rewrite(allowReprocessing: allowReprocessing, map)
        return a
    }
    
    func _rewrite(allowReprocessing: Bool = true, _ map: (Algebra) throws -> RewriteStatus<Algebra>) throws -> (Algebra, Bool) {
        let status = try map(self)
        switch status {
        case .keep:
            return (self, false)
        case .rewrite(let a):
            return (a, false)
        case .rewriteChildren(let a):
            switch a {
            case .subquery(let q):
                let qq = try q.rewrite(map)
                return (.subquery(qq), false)
            case .unionIdentity, .joinIdentity, .triple, .quad, .path, .bgp, .table:
                let rewritten : Algebra = a
                return (rewritten, true)
            case .distinct(let a):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .distinct(aa)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .reduced(let a):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .reduced(aa)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .project(let a, let p):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .project(aa, p)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, false)
            case .order(let a, let cmps):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .order(aa, cmps)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, false)
            case .minus(let a, let b):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                let (bb, rb) = try b._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .minus(aa, bb)
                if allowReprocessing && (ra || rb) {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .union(let a, let b):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                let (bb, rb) = try b._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .union(aa, bb)
                if allowReprocessing && (ra || rb) {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .innerJoin(let a, let b):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                let (bb, rb) = try b._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .innerJoin(aa, bb)
                if allowReprocessing && (ra || rb) {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .leftOuterJoin(let a, let b, let expr):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                let (bb, rb) = try b._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .leftOuterJoin(aa, bb, expr)
                if allowReprocessing && (ra || rb) {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .extend(let a, let expr, let v):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .extend(aa, expr, v)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .filter(let a, let expr):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .filter(aa, expr)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .namedGraph(let a, let node):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .namedGraph(aa, node)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .slice(let a, let offset, let limit):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .slice(aa, offset, limit)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .service(let endpoint, let a, let silent):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .service(endpoint, aa, silent)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, false)
            case .aggregate(let a, let exprs, let aggs):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .aggregate(aa, exprs, aggs)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            case .window(let a, let funcs):
                var (aa, ra) = try a._rewrite(allowReprocessing: allowReprocessing, map)
                var rewritten : Algebra = .window(aa, funcs)
                if allowReprocessing && ra {
                    (rewritten, ra) = try rewritten._rewrite(allowReprocessing: false, map)
                }
                return (rewritten, ra)
            }
        }
    }
    
    func bind(_ variable: String, to replacement: Node, preservingProjection: Bool = false) throws -> Algebra {
        var r = self
        r = try r.replace { (expr: Expression) -> Expression? in
            if case .node(.variable(let name, _)) = expr {
                if name == variable {
                    return .node(replacement)
                }
            }
            return nil
        }
        
        r = try r.replace { (algebra: Algebra) throws -> Algebra? in
            switch algebra {
            case .triple(let t):
                return .triple(t.bind(variable, to: replacement))
            case .quad(let q):
                return .quad(q.bind(variable, to: replacement))
            case .path(let subj, let pp, let obj):
                let subj = subj.bind(variable, to: replacement)
                let obj = obj.bind(variable, to: replacement)
                return .path(subj, pp, obj)
            case .bgp(let triples):
                return .bgp(triples.map { $0.bind(variable, to: replacement) })
            case .project(let a, let p):
                let child = try a.bind(variable, to: replacement)
                if preservingProjection {
                    let extend: Algebra = .extend(child, .node(replacement), variable)
                    return .project(extend, p)
                } else {
                    return .project(child, p.filter { $0 != variable })
                }
            case .namedGraph(let a, let node):
                return try .namedGraph(
                    a.bind(variable, to: replacement),
                    node.bind(variable, to: replacement)
                )
            default:
                break
            }
            return nil
        }
        return r
    }
}
