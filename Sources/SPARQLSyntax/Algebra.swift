import Foundation

public enum WindowFunction {
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
    public typealias SortComparator = (Bool, Expression)
    
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
    case service(Node, Algebra, Bool)
    case slice(Algebra, Int?, Int?)
    case order(Algebra, [SortComparator])
    case path(Node, PropertyPath, Node)
    case aggregate(Algebra, [Expression], [(Aggregation, String)])
    case window(Algebra, [Expression], [(WindowFunction, [SortComparator], String)])
    case subquery(Query)
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
                guard lcmp.0 == rcmp.0 else { return false }
                guard lcmp.1 == rcmp.1 else { return false }
            }
            return true
        case (.path(let ls, let lp, let lo), .path(let rs, let rp, let ro)) where ls == rs && lp == rp && lo == ro:
            return true
        case (.aggregate(let ls, let lp, let lo), .aggregate(let rs, let rp, let ro)) where ls == rs && lp == rp:
            guard lo.count == ro.count else { return false }
            for (l, r) in zip(lo, ro) {
                guard l.0 == r.0 else { return false }
                guard l.1 == r.1 else { return false }
            }
            return true
        case (.window(let ls, let lp, let lo), .window(let rs, let rp, let ro)) where ls == rs && lp == rp:
            guard lo.count == ro.count else { return false }
            for (l, r) in zip(lo, ro) {
                guard l.0 == r.0 else { return false }
                guard l.2 == r.2 else { return false }
                guard l.1.count == r.1.count else { return false }
                for (lcmp, rcmp) in zip(l.1 ,r.1) {
                    guard lcmp.0 == rcmp.0 else { return false }
                    guard lcmp.1 == rcmp.1 else { return false }
                }
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
            var d = "\(indent)Project \(variables)\n"
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
            let expressions = orders.map { $0.0 ? "\($0.1)" : "DESC(\($0.1))" }
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
            let orders = funcs.flatMap { $0.1 }
            let expressions = orders.map { $0.0 ? "\($0.1)" : "DESC(\($0.1))" }
            let f = funcs.map { ($0.0, $0.2) }
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
            for (_, name) in aggs {
                variables.insert(name)
            }
            return variables
        case .window(let child, _, let funcs):
            var variables = child.inscope
            for (_, _, name) in funcs {
                variables.insert(name)
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
        case .aggregate(_, let groups, _):
            var vars = Set<String>()
            for g in groups {
                if case .node(.variable(let v, _)) = g {
                    vars.insert(v)
                }
            }
            return vars
            
        case .extend(let child, _, let v):
            return Set([v]).union(child.projectableVariables)
            
        default:
            return self.inscope
        }
    }
    
    public var isAggregation: Bool {
        switch self {
        case .joinIdentity, .unionIdentity, .triple(_), .quad(_), .bgp(_), .path(_), .window(_), .table(_), .subquery(_):
            return false
            
        case .project(let child, _), .minus(let child, _), .distinct(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _):
            return child.isAggregation
            
        case .innerJoin(let lhs, let rhs), .union(let lhs, let rhs), .leftOuterJoin(let lhs, let rhs, _):
            return lhs.isAggregation || rhs.isAggregation
            
        case .aggregate(_):
            return true
        case .extend(let child, let expr, _), .filter(let child, let expr):
            if child.isAggregation {
                return true
            }
            return expr.hasAggregation
        }
    }
}

public extension Algebra {
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
            return try .order(a.replace(map), cmps.map { (asc, expr) in try (asc, expr.replace(map)) })
        case .aggregate(let a, let exprs, let aggs):
            // case aggregate(Algebra, [Expression], [(Aggregation, String)])
            let exprs = try exprs.map { (expr) in
                return try expr.replace(map)
            }
            let aggs = try aggs.map { (agg, name) in
                return try (agg.replace(map), name)
            }
            return try .aggregate(a.replace(map), exprs, aggs)
        case .window(let a, let exprs, let funcs):
            //     case window(Algebra, [Expression], [(WindowFunction, [SortComparator], String)])
            let exprs = try exprs.map { (expr) in
                return try expr.replace(map)
            }
            let funcs = try funcs.map { (f, cmps, name) -> (WindowFunction, [SortComparator], String) in
                let e = try cmps.map { (asc, expr) in try (asc, expr.replace(map)) }
                return (f, e, name)
            }
            return try .window(a.replace(map), exprs, funcs)
        }
    }
    
    func replace(_ map: (Algebra) throws -> Algebra?) throws -> Algebra {
        if let r = try map(self) {
            return r
        } else {
            switch self {
            case .subquery(let q):
                return try .subquery(q.replace(map))
            case .unionIdentity, .joinIdentity, .triple(_), .quad(_), .path(_), .bgp(_), .table(_):
                return self
            case .distinct(let a):
                return try .distinct(a.replace(map))
            case .project(let a, let p):
                return try .project(a.replace(map), p)
            case .order(let a, let cmps):
                return try .order(a.replace(map), cmps)
            case .minus(let a, let b):
                return try .minus(a.replace(map), b.replace(map))
            case .union(let a, let b):
                return try .union(a.replace(map), b.replace(map))
            case .innerJoin(let a, let b):
                return try .innerJoin(a.replace(map), b.replace(map))
            case .leftOuterJoin(let a, let b, let expr):
                return try .leftOuterJoin(a.replace(map), b.replace(map), expr)
            case .extend(let a, let expr, let v):
                return try .extend(a.replace(map), expr, v)
            case .filter(let a, let expr):
                return try .filter(a.replace(map), expr)
            case .namedGraph(let a, let node):
                return try .namedGraph(a.replace(map), node)
            case .slice(let a, let offset, let limit):
                return try .slice(a.replace(map), offset, limit)
            case .service(let endpoint, let a, let silent):
                return try .service(endpoint, a.replace(map), silent)
            case .aggregate(let a, let exprs, let aggs):
                return try .aggregate(a.replace(map), exprs, aggs)
            case .window(let a, let exprs, let funcs):
                return try .window(a.replace(map), exprs, funcs)
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
