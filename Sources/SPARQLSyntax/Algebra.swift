import Foundation

public enum RewriteStatus<A> {
    case keep
    case rewriteChildren(A)
    case rewrite(A)
}

public enum WindowFunction : String, Codable {
    case rowNumber
    case rank
}

public indirect enum PropertyPath {
    case link(Term)
    case inv(PropertyPath)
    case nps([Term])
    case alt(PropertyPath, PropertyPath)
    case seq(PropertyPath, PropertyPath)
    case plus(PropertyPath)
    case star(PropertyPath)
    case zeroOrOne(PropertyPath)
}

extension PropertyPath : Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case link
        case lhs
        case rhs
        case terms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "link":
            let term = try container.decode(Term.self, forKey: .link)
            self = .link(term)
        case "inv":
            let pp = try container.decode(PropertyPath.self, forKey: .lhs)
            self = .inv(pp)
        case "nps":
            let terms = try container.decode([Term].self, forKey: .terms)
            self = .nps(terms)
        case "alt":
            let lhs = try container.decode(PropertyPath.self, forKey: .lhs)
            let rhs = try container.decode(PropertyPath.self, forKey: .rhs)
            self = .alt(lhs, rhs)
        case "seq":
            let lhs = try container.decode(PropertyPath.self, forKey: .lhs)
            let rhs = try container.decode(PropertyPath.self, forKey: .rhs)
            self = .seq(lhs, rhs)
        case "plus":
            let pp = try container.decode(PropertyPath.self, forKey: .lhs)
            self = .plus(pp)
        case "star":
            let pp = try container.decode(PropertyPath.self, forKey: .lhs)
            self = .star(pp)
        case "zeroOrOne":
            let pp = try container.decode(PropertyPath.self, forKey: .lhs)
            self = .zeroOrOne(pp)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected property path type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .link(let term):
            try container.encode("link", forKey: .type)
            try container.encode(term, forKey: .link)
        case .inv(let pp):
            try container.encode("inv", forKey: .type)
            try container.encode(pp, forKey: .lhs)
        case .nps(let terms):
            try container.encode("nps", forKey: .type)
            try container.encode(terms, forKey: .terms)
        case let .alt(lhs, rhs):
            try container.encode("alt", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case let .seq(lhs, rhs):
            try container.encode("seq", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(rhs, forKey: .rhs)
        case .plus(let pp):
            try container.encode("plus", forKey: .type)
            try container.encode(pp, forKey: .lhs)
        case .star(let pp):
            try container.encode("star", forKey: .type)
            try container.encode(pp, forKey: .lhs)
        case .zeroOrOne(let pp):
            try container.encode("zeroOrOne", forKey: .type)
            try container.encode(pp, forKey: .lhs)
        }
    }
}

extension PropertyPath: CustomStringConvertible {
    public var description: String {
        switch self {
        case .link(let t):
            return t.description
        case .inv(let pp):
            return "inv(\(pp))"
        case .nps(let pp):
            return "NPS(\(pp))"
        case let .alt(lhs, rhs):
            return "alt(\(lhs), \(rhs))"
        case let .seq(lhs, rhs):
            return "seq(\(lhs), \(rhs))"
        case .plus(let pp):
            return "oneOrMore(\(pp))"
        case .star(let pp):
            return "zeroOrMore(\(pp))"
        case .zeroOrOne(let pp):
            return "zeroOrOne(\(pp))"
        }
    }
}

extension PropertyPath : Equatable {
    public static func == (lhs: PropertyPath, rhs: PropertyPath) -> Bool {
        switch (lhs, rhs) {
        case (.link(let l), .link(let r)) where l == r:
            return true
        case (.inv(let l), .inv(let r)) where l == r:
            return true
        case (.nps(let l), .nps(let r)) where l == r:
            return true
        case (.alt(let ll, let lr), .alt(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.seq(let ll, let lr), .seq(let rl, let rr)) where ll == rl && lr == rr:
            return true
        case (.plus(let l), .plus(let r)) where l == r:
            return true
        case (.star(let l), .star(let r)) where l == r:
            return true
        case (.zeroOrOne(let l), .zeroOrOne(let r)) where l == r:
            return true
        default:
            return false
        }
    }
}

public indirect enum Algebra {
    public struct SortComparator : Equatable, Codable {
        public var ascending: Bool
        public var expression: Expression
        
        public init(ascending: Bool, expression: Expression) {
            self.ascending = ascending
            self.expression = expression
        }
        
        public func sparqlTokens() throws -> AnySequence<SPARQLToken> {
            var tokens = [SPARQLToken]()
            var exprTokens = try Array(expression.sparqlTokens())
            if !(exprTokens.prefix(upTo: 1) == [.lparen]) {
                switch expression {
                case .call(_, _), .node(.variable(_)):
                    break
                default:
                    exprTokens = [.lparen] + exprTokens + [.rparen]
                }
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
    }
    
    public struct AggregationMapping: Equatable, Codable {
        public var aggregation: Aggregation
        public var variableName: String
        
        public init(aggregation: Aggregation, variableName: String) {
            self.aggregation = aggregation
            self.variableName = variableName
        }
    }
    
    public struct WindowFunctionMapping: Equatable, Codable {
        public var windowFunction: WindowFunction
        public var comparators: [SortComparator]
        public var variableName: String

        public init(windowFunction: WindowFunction, comparators: [SortComparator], variableName: String) {
            self.windowFunction = windowFunction
            self.comparators = comparators
            self.variableName = variableName
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
    case service(URL, Algebra, Bool)
    case slice(Algebra, Int?, Int?)
    case order(Algebra, [SortComparator])
    case path(Node, PropertyPath, Node)
    case aggregate(Algebra, [Expression], [AggregationMapping])
    case window(Algebra, [Expression], [WindowFunctionMapping])
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
            let rhs = try container.decode(Algebra.self, forKey: .lhs)
            self = .innerJoin(lhs, rhs)
        case "leftOuterJoin":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .lhs)
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .leftOuterJoin(lhs, rhs, expr)
        case "filter":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let expr = try container.decode(Expression.self, forKey: .expression)
            self = .filter(lhs, expr)
        case "union":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let rhs = try container.decode(Algebra.self, forKey: .lhs)
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
            let rhs = try container.decode(Algebra.self, forKey: .lhs)
            self = .minus(lhs, rhs)
        case "project":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let vars = try container.decode(Set<String>.self, forKey: .variables)
            self = .project(lhs, vars)
        case "distinct":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            self = .distinct(lhs)
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
            let aggs = try container.decode([AggregationMapping].self, forKey: .aggregations)
            self = .aggregate(lhs, groups, aggs)
        case "window":
            let lhs = try container.decode(Algebra.self, forKey: .lhs)
            let groups = try container.decode([Expression].self, forKey: .groups)
            let windows = try container.decode([WindowFunctionMapping].self, forKey: .windowFunctions)
            self = .window(lhs, groups, windows)
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
        case let .window(lhs, groups, windows):
            try container.encode("window", forKey: .type)
            try container.encode(lhs, forKey: .lhs)
            try container.encode(groups, forKey: .groups)
            try container.encode(windows, forKey: .windowFunctions)
        case .subquery(let q):
            try container.encode("query", forKey: .type)
            try container.encode(q, forKey: .query)
        }
    }
}


extension Algebra : Equatable {
    public static func == (lhs: Algebra, rhs: Algebra) -> Bool {
        switch (lhs, rhs) {
        case (.unionIdentity, .unionIdentity), (.joinIdentity, .joinIdentity):
            return true
        case (.table(let ln, let lr), .table(let rn, let rr)) where ln == rn && lr == rr:
            return true
        case (.quad(let l), .quad(let r)) where l == r:
            return true
        case (.triple(let l), .triple(let r)) where l == r:
            return true
        case (.bgp(let l), .bgp(let r)) where l == r:
            return true
        case (.innerJoin(let l), .innerJoin(let r)) where l == r:
            return true
        case (.leftOuterJoin(let l), .leftOuterJoin(let r)) where l == r:
            return true
        case (.union(let l), .union(let r)) where l == r:
            return true
        case (.minus(let l), .minus(let r)) where l == r:
            return true
        case (.distinct(let l), .distinct(let r)) where l == r:
            return true
        case (.subquery(let l), .subquery(let r)) where l == r:
            return true
        case (.filter(let la, let le), .filter(let ra, let re)) where la == ra && le == re:
            return true
        case (.namedGraph(let la, let ln), .namedGraph(let ra, let rn)) where la == ra && ln == rn:
            return true
        case (.extend(let la, let le, let ln), .extend(let ra, let re, let rn)) where la == ra && le == re && ln == rn:
            return true
        case (.project(let la, let lv), .project(let ra, let rv)) where la == ra && lv == rv:
            return true
        case (.service(let ln, let la, let ls), .service(let rn, let ra, let rs)) where la == ra && ln == rn && ls == rs:
            return true
        case (.slice(let la, let ll, let lo), .slice(let ra, let rl, let ro)) where la == ra && ll == rl && lo == ro:
            return true
        case (.order(let la, let lc), .order(let ra, let rc)) where la == ra:
            guard lc.count == rc.count else { return false }
            for (lcmp, rcmp) in zip(lc, rc) {
                guard lcmp == rcmp else { return false }
            }
            return true
        case (.path(let ls, let lp, let lo), .path(let rs, let rp, let ro)) where ls == rs && lp == rp && lo == ro:
            return true
        case (.aggregate(let ls, let lp, let lo), .aggregate(let rs, let rp, let ro)) where ls == rs && lp == rp:
            guard lo.count == ro.count else { return false }
            for (l, r) in zip(lo, ro) {
                guard l == r else { return false }
            }
            return true
        case (.window(let ls, let lp, let lo), .window(let rs, let rp, let ro)) where ls == rs && lp == rp:
            guard lo.count == ro.count else { return false }
            for (l, r) in zip(lo, ro) {
                guard l == r else { return false }
            }
            return true
        default:
            return false
        }
    }
}

public extension Algebra {
    // swiftlint:disable:next cyclomatic_complexity
    public func serialize(depth: Int=0) -> String {
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
            var d = "\(indent)Extend \(name) <- \(expr)\n"
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
        case .window(let child, let groups, let funcs):
            let orders = funcs.flatMap { $0.comparators }
            let expressions = orders.map { $0.ascending ? "\($0.expression)" : "DESC(\($0.expression))" }
            let f = funcs.map { ($0.windowFunction, $0.variableName) }
            var d = "\(indent)Window \(f) over groups \(groups) ordered by { \(expressions.joined(separator: ", ")) }\n"
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
    
    public var inscope: Set<String> {
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
        case .filter(let child, _), .minus(let child, _), .distinct(let child), .slice(let child, _, _), .namedGraph(let child, .bound(_)), .order(let child, _), .service(_, let child, _):
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
        case .window(let child, _, let funcs):
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
    
    public var projectableVariables : Set<String> {
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
        case .joinIdentity, .unionIdentity, .triple(_), .quad(_), .bgp(_), .path(_), .window(_), .table(_), .subquery(_):
            return [:]
            
        case .project(let child, _), .minus(let child, _), .distinct(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _), .filter(let child, _):
            return child.variableExtensions
            
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs), .leftOuterJoin(let lhs, let rhs, _):
            let le = lhs.variableExtensions
            let re = rhs.variableExtensions
            return le.merging(re) { (l,r) in l }
            
        case .aggregate(_):
            return [:]

        case let .extend(child, expr, name):
            var d = child.variableExtensions
            d[name] = expr
            return d
        }
    }
    
    public var aggregation: Algebra? {
        switch self {
        case .joinIdentity, .unionIdentity, .triple(_), .quad(_), .bgp(_), .path(_), .window(_), .table(_), .subquery(_):
            return nil
            
        case .project(let child, _), .minus(let child, _), .distinct(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _):
            return child.aggregation
            
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs), .leftOuterJoin(let lhs, let rhs, _):
            return lhs.aggregation ?? rhs.aggregation
            
        case .aggregate(_):
            return self
        case .extend(let child, _, _), .filter(let child, _):
            return child.aggregation
        }
    }

    public var isAggregation: Bool {
        if let _ = aggregation {
            return true
        } else {
            return false
        }
    }
}

public extension Algebra {
    func replace(_ map: [String:Term]) throws -> Algebra {
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
                            return .bound(t)
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
                            return .bound(t)
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
                                return .bound(t)
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
                        subj = .bound(t)
                    }
                }
                if case .variable(let name, _) = o {
                    if let t = map[name] {
                        obj = .bound(t)
                    }
                }
                return .path(subj, pp, obj)
            case let .project(a, vars):
                return try .project(a.replace(map), vars)
            case let .namedGraph(a, g):
                var graph = g
                if case .variable(let name, _) = g {
                    if let t = map[name] {
                        graph = .bound(t)
                    }
                }
                return try .namedGraph(a.replace(map), graph)
            case .subquery(let q):
                return try .subquery(q.replace(map))
            case .unionIdentity, .joinIdentity:
                return self
            case .distinct(let a):
                return try .distinct(a.replace(map))
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
                return try .aggregate(a.replace(map), exprs, aggs)
            case .window(let a, let exprs, let funcs):
                let exprs = try exprs.map { (expr) in
                    return try expr.replace(map)
                }
                let funcs = try funcs.map { data -> WindowFunctionMapping in
                    let e = try data.comparators.map { cmp in
                        try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
                    }
                    return WindowFunctionMapping(
                        windowFunction: data.windowFunction,
                        comparators: e,
                        variableName: data.variableName
                    )
                }
                return try .window(a.replace(map), exprs, funcs)


            }
        })
    }
    
    func replace(_ map: (Expression) throws -> Expression?) throws -> Algebra {
        switch self {
        case .subquery(let q):
            return try .subquery(q.replace(map))
        case .unionIdentity, .joinIdentity, .triple(_), .quad(_), .path(_), .bgp(_), .table(_):
            return self
        case .distinct(let a):
            return try .distinct(a.replace(map))
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
            return try .aggregate(a.replace(map), exprs, aggs)
        case .window(let a, let exprs, let funcs):
            //     case window(Algebra, [Expression], [WindowFunctionMapping])
            let exprs = try exprs.map { (expr) in
                return try expr.replace(map)
            }
            let funcs = try funcs.map { data -> WindowFunctionMapping in
                let e = try data.comparators.map { cmp in
                    try SortComparator(ascending: cmp.ascending, expression: cmp.expression.replace(map))
                }
                return WindowFunctionMapping(
                    windowFunction: data.windowFunction,
                    comparators: e,
                    variableName: data.variableName
                )
            }
            return try .window(a.replace(map), exprs, funcs)
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
    
    public func rewrite(_ map: (Algebra) throws -> RewriteStatus<Algebra>) throws -> Algebra {
        let status = try map(self)
        switch status {
        case .keep:
            return self
        case .rewrite(let a):
            return a
        case .rewriteChildren(let a):
            switch a {
            case .subquery(let q):
                return try .subquery(q.rewrite(map))
            case .unionIdentity, .joinIdentity, .triple(_), .quad(_), .path(_), .bgp(_), .table(_):
                return a
            case .distinct(let a):
                return try .distinct(a.rewrite(map))
            case .project(let a, let p):
                return try .project(a.rewrite(map), p)
            case .order(let a, let cmps):
                return try .order(a.rewrite(map), cmps)
            case .minus(let a, let b):
                return try .minus(a.rewrite(map), b.rewrite(map))
            case .union(let a, let b):
                return try .union(a.rewrite(map), b.rewrite(map))
            case .innerJoin(let a, let b):
                return try .innerJoin(a.rewrite(map), b.rewrite(map))
            case .leftOuterJoin(let a, let b, let expr):
                return try .leftOuterJoin(a.rewrite(map), b.rewrite(map), expr)
            case .extend(let a, let expr, let v):
                return try .extend(a.rewrite(map), expr, v)
            case .filter(let a, let expr):
                return try .filter(a.rewrite(map), expr)
            case .namedGraph(let a, let node):
                return try .namedGraph(a.rewrite(map), node)
            case .slice(let a, let offset, let limit):
                return try .slice(a.rewrite(map), offset, limit)
            case .service(let endpoint, let a, let silent):
                return try .service(endpoint, a.rewrite(map), silent)
            case .aggregate(let a, let exprs, let aggs):
                return try .aggregate(a.rewrite(map), exprs, aggs)
            case .window(let a, let exprs, let funcs):
                return try .window(a.rewrite(map), exprs, funcs)
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
