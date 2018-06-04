import Foundation

private func joinReduction(coalesceBGPs: Bool = false) -> (Algebra, Algebra) -> Algebra {
    return { (lhs, rhs) in
        switch (lhs, rhs) {
        case (.joinIdentity, _):
            return rhs
        case let (.bgp(triples), .triple(t)) where coalesceBGPs:
            return .bgp(triples + [t])
        case let (.triple(t), .bgp(triples)) where coalesceBGPs:
            return .bgp([t] + triples)
        case let (.triple(lt), .triple(rt)) where coalesceBGPs:
            return .bgp([lt, rt])
        default:
            return .innerJoin(lhs, rhs)
        }
    }
}

private enum UnfinishedAlgebra {
    case filter(Expression)
    case optional(Algebra)
    case minus(Algebra)
    case bind(Expression, String)
    case finished(Algebra)
    
    func finish(_ args: inout [Algebra]) throws -> Algebra {
        switch self {
        case .bind(let e, let name):
            let algebra: Algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
            args = []
            if algebra.inscope.contains(name) {
                throw SPARQLSyntaxError.parsingError("Cannot BIND to an already in-scope variable (?\(name)") // TODO: can the line:col be included in this exception?
            }
            return .extend(algebra, e, name)
        case .filter(let expr):
            let algebra: Algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
            args = []
            if case let .filter(a, e) = algebra {
                return .filter(a, .and(expr, e))
            } else {
                return .filter(algebra, expr)
            }
        case .minus(let a):
            let algebra: Algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
            args = []
            return .minus(algebra, a)
        case .optional(.filter(let a, let e)):
            let algebra: Algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
            args = []
            return .leftOuterJoin(algebra, a, e)
        case .optional(let a):
            let e: Expression = .node(.bound(Term.trueValue))
            let algebra: Algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
            args = []
            return .leftOuterJoin(algebra, a, e)
        case .finished(let a):
            return a
        }
    }
}

// swiftlint:disable:next type_body_length
public struct SPARQLParser {
    public var parseBlankNodesAsVariables: Bool
    var lexer: SPARQLLexer
    var prefixes: [String:String]
    var bnodes: [String:Node]
    var base: String?
    var tokenLookahead: SPARQLToken?
    var freshCounter = AnyIterator(sequence(first: 1) { $0 + 1 })
    var seenBlankNodeLabels: Set<String>
    
    private mutating func parseError(_ message: String) -> SPARQLSyntaxError {
        try? lexer.fillBuffer()
        let rest = lexer.buffer
        return SPARQLSyntaxError.parsingError("\(message) at \(lexer.line):\(lexer.column) near '\(rest)...'")
    }
    
    public init(lexer: SPARQLLexer, prefixes: [String:String] = [:], base: String? = nil) {
        self.lexer = lexer
        self.prefixes = prefixes
        self.base = base
        self.bnodes = [:]
        self.seenBlankNodeLabels = Set()
        self.parseBlankNodesAsVariables = true
    }
    
    public init?(string: String, prefixes: [String:String] = [:], base: String? = nil, includeComments: Bool = false) {
        guard let data = string.data(using: .utf8) else { return nil }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream, includeComments: includeComments)
        self.init(lexer: lexer, prefixes: prefixes, base: base)
    }
    
    public init?(data: Data, prefixes: [String:String] = [:], base: String? = nil, includeComments: Bool = false) {
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream, includeComments: includeComments)
        self.init(lexer: lexer, prefixes: prefixes, base: base)
    }
    
    private mutating func bnode(named name: String? = nil) -> Node {
        if let name = name, let node = self.bnodes[name] {
            return node
        } else {
            guard let id = freshCounter.next() else { fatalError("No fresh variable available") }
            let b: Node = .bound(Term(value: "b\(id)", type: .blank))
            if let name = name {
                self.bnodes[name] = b
            }
            return b
        }
    }
    
    private mutating func peekToken() -> SPARQLToken? {
        if tokenLookahead == nil {
            tokenLookahead = self.lexer.next()
        }
        return tokenLookahead
    }
    
    private mutating func peekExpectedToken() throws -> SPARQLToken {
        guard let t = peekToken() else {
            throw parseError("Unexpected EOF")
        }
        return t
    }
    
    private mutating func nextExpectedToken() throws -> SPARQLToken {
        guard let t = nextToken() else {
            throw parseError("Unexpected EOF")
        }
        return t
    }
    
    @discardableResult
    private mutating func nextToken() -> SPARQLToken? {
        if let t = tokenLookahead {
            tokenLookahead = nil
            return t
        } else {
            return self.lexer.next()
        }
    }
    
    private mutating func peek(token: SPARQLToken) throws -> Bool {
        guard let t = peekToken() else { return false }
        if t == token {
            return true
        } else {
            return false
        }
    }
    
    @discardableResult
    private mutating func attempt(token: SPARQLToken) throws -> Bool {
        if try peek(token: token) {
            nextToken()
            return true
        } else {
            return false
        }
    }
    
    private mutating func expect(token: SPARQLToken) throws {
        guard let t = nextToken() else {
            throw parseError("Expected \(token) but got EOF")
        }
        guard t == token else {
            throw parseError("Expected \(token) but got \(t)")
        }
        return
    }
    
    public mutating func parseQuery() throws -> Query {
        try parsePrologue()
        
        let t = try peekExpectedToken()
        guard case .keyword(let kw) = t else { throw parseError("Expected query method not found") }
        
        var query: Query
        switch kw {
        case "SELECT":
            query = try parseSelectQuery()
        case "CONSTRUCT":
            query = try parseConstructQuery()
        case "DESCRIBE":
            query = try parseDescribeQuery()
        case "ASK":
            query = try parseAskQuery()
        default:
            throw parseError("Expected query method not found: \(kw)")
        }
        if let extra = peekToken() {
            throw parseError("Expected EOF, but found: \(extra)")
        } else if lexer.hasRemainingContent {
            throw parseError("Expected EOF, but found extra content: <<\(lexer.buffer)>>")
        }
        return query
    }
    
    public mutating func parseAlgebra() throws -> Algebra {
        let query : Query = try self.parseQuery()
        return query.algebra
    }
    
    private mutating func parsePrologue() throws {
        while true {
            if try attempt(token: .keyword("PREFIX")) {
                let pn = try nextExpectedToken()
                guard case .prefixname(let name, "") = pn else { throw parseError("Expected prefix name but found \(pn)") }
                let iri = try nextExpectedToken()
                guard case .iri(let value) = iri else { throw parseError("Expected prefix IRI but found \(iri)") }
                self.prefixes[name] = value
            } else if try attempt(token: .keyword("BASE")) {
                let iri = try nextExpectedToken()
                guard case .iri(let value) = iri else { throw parseError("Expected BASE IRI but found \(iri)") }
                self.base = value
            } else {
                break
            }
        }
    }
    
    private mutating func parseSelectQuery() throws -> Query {
        try expect(token: .keyword("SELECT"))
        var distinct = false
        var aggregationExpressions = [String:Aggregation]()
        var projectExpressions = [(Expression, String)]()
        
        if try attempt(token: .keyword("DISTINCT")) || attempt(token: .keyword("REDUCED")) {
            distinct = true
        }
        
        
        var projection: SelectProjection
        if try attempt(token: .star) {
            projection = .star
        } else {
            var projectionVariables = [String]()
            LOOP: while true {
                let t = try peekExpectedToken()
                switch t {
                case .lparen:
                    try expect(token: .lparen)
                    var expression = try parseExpression()
                    if expression.hasAggregation {
                        expression = expression.removeAggregations(freshCounter, mapping: &aggregationExpressions)
                    }
                    try expect(token: .keyword("AS"))
                    let node = try parseVar()
                    guard case .variable(let name, binding: _) = node else {
                        throw parseError("Expecting project expressions variable but got \(node)")
                    }
                    try expect(token: .rparen)
                    projectExpressions.append((expression, name))
                    projectionVariables.append(name)
                case ._var(let name):
                    nextToken()
                    projectionVariables.append(name)
                default:
                    break LOOP
                }
            }
            projection = .variables(projectionVariables)
        }
        
        let dataset = try parseDatasetClauses()
        try attempt(token: .keyword("WHERE"))
        var algebra = try parseGroupGraphPattern()
        
        let values = try parseValuesClause()
        algebra = try parseSolutionModifier(algebra: algebra, distinct: distinct, projection: projection, projectExpressions: projectExpressions, aggregation: aggregationExpressions, valuesBlock: values)
        
        let query = try Query(form: .select(projection), algebra: algebra, dataset: dataset, base: self.base)
        return query
    }
    
    private mutating func parseConstructQuery() throws -> Query {
        try expect(token: .keyword("CONSTRUCT"))
        var pattern = [TriplePattern]()
        var hasTemplate = false
        if try peek(token: .lbrace) {
            hasTemplate = true
            pattern = try parseConstructTemplate()
        }
        let dataset = try parseDatasetClauses()
        try expect(token: .keyword("WHERE"))
        var algebra = try parseGroupGraphPattern()
        
        if !hasTemplate {
            switch algebra {
            case .triple(let triple):
                pattern = [triple]
            case .bgp(let triples):
                pattern = triples
            default:
                throw parseError("Unexpected construct template: \(algebra)")
            }
        }
        
        algebra = try parseSolutionModifier(algebra: algebra, distinct: true, projection: .star, projectExpressions: [], aggregation: [:], valuesBlock: nil)
        return try Query(form: .construct(pattern), algebra: algebra, dataset: dataset)
    }
    
    private mutating func parseDescribeQuery() throws -> Query {
        try expect(token: .keyword("DESCRIBE"))
        var star = false
        var describe = [Node]()
        if try attempt(token: .star) {
            star = true
        } else {
            let node = try parseVarOrIRI()
            describe.append(node)
            
            while let t = peekToken() {
                if t.isTerm {
                    describe.append(try parseVarOrIRI())
                } else if case ._var(_) = t {
                    describe.append(try parseVarOrIRI())
                } else {
                    break
                }
            }
        }
        
        let dataset = try parseDatasetClauses()
        try attempt(token: .keyword("WHERE"))
        let ggp: Algebra
        if try peek(token: .lbrace) {
            ggp = try parseGroupGraphPattern()
        } else {
            ggp = .joinIdentity
        }
        
        if star {
            
        }
        
        let algebra = try parseSolutionModifier(algebra: ggp, distinct: true, projection: .star, projectExpressions: [], aggregation: [:], valuesBlock: nil)
        return try Query(form: .describe(describe), algebra: algebra, dataset: dataset)
    }
    
    private mutating func parseConstructTemplate() throws -> [TriplePattern] {
        try expect(token: .lbrace)
        if try attempt(token: .rbrace) {
            return []
        } else {
            let tmpl = try parseTriplesBlock()
            try expect(token: .rbrace)
            return tmpl
        }
    }
    
    private mutating func parseTriplesBlock() throws -> [TriplePattern] {
        let sameSubj = try parseTriplesSameSubject()
        var t = try peekExpectedToken()
        if t == .none || t != .some(.dot) {
            return sameSubj
        } else {
            try expect(token: .dot)
            t = try peekExpectedToken()
            if t.isTermOrVar {
                let more = try parseTriplesBlock()
                return sameSubj + more
            } else {
                return sameSubj
            }
        }
    }
    
    private mutating func parseAskQuery() throws -> Query {
        try expect(token: .keyword("ASK"))
        let dataset = try parseDatasetClauses()
        try attempt(token: .keyword("WHERE"))
        let ggp = try parseGroupGraphPattern()
        return try Query(form: .ask, algebra: ggp, dataset: dataset)
    }
    
    private mutating func parseDatasetClauses() throws -> Dataset? {
        var named = [Term]()
        var unnamed = [Term]()
        while try attempt(token: .keyword("FROM")) {
            let namedIRI = try attempt(token: .keyword("NAMED"))
            let iri = try parseIRI()
            if namedIRI {
                named.append(iri)
            } else {
                unnamed.append(iri)
            }
        }
        
        return Dataset(defaultGraphs: unnamed, namedGraphs: named)
    }
    
    private mutating func parseGroupGraphPattern() throws -> Algebra {
        try expect(token: .lbrace)
        var algebra: Algebra
        
        if try peek(token: .keyword("SELECT")) {
            algebra = try parseSubSelect()
        } else {
            algebra = try parseGroupGraphPatternSub()
        }
        
        try expect(token: .rbrace)
        return algebra
    }
    
    private mutating func parseSubSelect() throws -> Algebra {
        try expect(token: .keyword("SELECT"))
        
        var distinct = false
        var star = false
        var aggregationExpressions = [String:Aggregation]()
        var projectExpressions = [(Expression, String)]()
        
        if try attempt(token: .keyword("DISTINCT")) || attempt(token: .keyword("REDUCED")) {
            distinct = true
        }
        
        var projection: SelectProjection
        if try attempt(token: .star) {
            projection = .star
            star = true
        } else {
            var projectionVariables = [String]()
            LOOP: while true {
                let t = try peekExpectedToken()
                switch t {
                case .lparen:
                    try expect(token: .lparen)
                    var expression = try parseExpression()
                    if expression.hasAggregation {
                        expression = expression.removeAggregations(freshCounter, mapping: &aggregationExpressions)
                    }
                    try expect(token: .keyword("AS"))
                    let node = try parseVar()
                    guard case .variable(let name, binding: _) = node else {
                        throw parseError("Expecting project expressions variable but got \(node)")
                    }
                    try expect(token: .rparen)
                    projectExpressions.append((expression, name))
                    projectionVariables.append(name)
                case ._var(let name):
                    nextToken()
                    projectionVariables.append(name)
                default:
                    break LOOP
                }
            }
            projection = .variables(projectionVariables)
        }
        
        try attempt(token: .keyword("WHERE"))
        var algebra = try parseGroupGraphPattern()
        
        let values = try parseValuesClause()
        
        algebra = try parseSolutionModifier(algebra: algebra, distinct: distinct, projection: projection, projectExpressions: projectExpressions, aggregation: aggregationExpressions, valuesBlock: values)
        
        if star {
            if algebra.isAggregation {
                throw parseError("Aggregation subqueries cannot use a `SELECT *`")
            }
        }
        
        return try .subquery(Query(form: .select(projection), algebra: algebra, dataset: nil))
    }
    
    private mutating func parseGroupCondition(_ algebra: inout Algebra) throws -> Node? {
        var node: Node
        if try attempt(token: .lparen) {
            let expr = try parseExpression()
            if try attempt(token: .keyword("AS")) {
                node = try parseVar()
                guard case .variable(let name, binding: _) = node else {
                    throw parseError("Expecting GROUP variable name but got \(node)")
                }
                algebra = .extend(algebra, expr, name)
            } else {
                guard let c = freshCounter.next() else { fatalError("No fresh variable available") }
                let name = ".group-\(c)"
                algebra = .extend(algebra, expr, name)
                node = .variable(name, binding: true)
            }
            try expect(token: .rparen)
            return node
        } else {
            guard let t = peekToken() else { return nil }
            if case ._var(_) = t {
                node = try parseVar()
                guard case .variable(_) = node else {
                    throw parseError("Expecting GROUP variable but got \(node)")
                }
                return node
            } else {
                let expr = try parseBuiltInCall()
                guard let c = freshCounter.next() else { fatalError("No fresh variable available") }
                let name = ".group-\(c)"
                algebra = .extend(algebra, expr, name)
                node = .variable(name, binding: true)
                return node
            }
        }
    }
    
    private mutating func parseOrderCondition() throws -> Algebra.SortComparator? {
        var ascending = true
        var forceBrackettedExpression = false
        if try attempt(token: .keyword("ASC")) {
            forceBrackettedExpression = true
        } else if try attempt(token: .keyword("DESC")) {
            forceBrackettedExpression = true
            ascending = false
        }
        
        var expr: Expression
        guard let t = peekToken() else { return nil }
        if try forceBrackettedExpression || peek(token: .lparen) {
            expr = try parseBrackettedExpression()
        } else if case ._var(_) = t {
            expr = try .node(parseVarOrTerm())
        } else if let e = try? parseConstraint() {
            expr = e
        } else {
            return nil
        }
        return Algebra.SortComparator(ascending: ascending, expression: expr)
    }
    
    private mutating func parseConstraint() throws -> Expression {
        if try peek(token: .lparen) {
            return try parseBrackettedExpression()
        } else {
            let t = try peekExpectedToken()
            switch t {
            case .iri(_), .prefixname(_, _):
                return try parseFunctionCall()
            default:
                let expr = try parseBuiltInCall()
                return expr
            }
        }
    }
    
    private mutating func parseFunctionCall() throws -> Expression {
        let expr = try parseIRIOrFunction()
        return expr
    }
    
    // swiftlint:disable:next function_parameter_count
    private mutating func parseSolutionModifier(algebra: Algebra, distinct: Bool, projection: SelectProjection, projectExpressions: [(Expression, String)], aggregation: [String:Aggregation], valuesBlock: Algebra?) throws -> Algebra {
        var algebra = algebra
        
        var groups = [Expression]()
        var applyAggregation: Bool = false
        if try attempt(token: .keyword("GROUP")) {
            applyAggregation = true
            try expect(token: .keyword("BY"))
            while let n = try? parseGroupCondition(&algebra), let node = n {
                groups.append(.node(node))
            }
        }
        
        var aggregation = aggregation
        var havingExpression: Expression? = nil
        if try attempt(token: .keyword("HAVING")) {
            var e = try parseConstraint()
            if e.hasAggregation {
                e = e.removeAggregations(freshCounter, mapping: &aggregation)
            }
            havingExpression = e
        }
        
        let aggregations = aggregation.map {
            Algebra.AggregationMapping(aggregation: $0.1, variableName: $0.0) }.sorted { $0.variableName <= $1.variableName }
        if aggregations.count > 0 { // if algebra contains aggregation
            applyAggregation = true
        }

        if applyAggregation {
            algebra = .aggregate(algebra, groups, aggregations)
        }

        let inScope = algebra.inscope
        for (_, name) in projectExpressions {
            if inScope.contains(name) {
                throw parseError("Cannot bind an already used variable (?\(name) in a select expression")
            }
        }
        
        algebra = projectExpressions.reduce(algebra) {
            addAggregationExtension(to: $0, expression: $1.0, variableName: $1.1)
        }
        
        if let e = havingExpression {
            algebra = .filter(algebra, e)
        }
        
        if let values = valuesBlock {
            algebra = .innerJoin(algebra, values)
        }
        
        var sortConditions: [Algebra.SortComparator] = []
        if try attempt(token: .keyword("ORDER")) {
            try expect(token: .keyword("BY"))
            while true {
                guard let c = try parseOrderCondition() else { break }
                sortConditions.append(c)
            }
            if sortConditions.count > 0 {
                algebra = .order(algebra, sortConditions)
            }
        }
        
        if case .variables(let projection) = projection {
            algebra = .project(algebra, Set(projection))
        }
        
        if distinct {
            algebra = .distinct(algebra)
        }
        
        if try attempt(token: .keyword("LIMIT")) {
            let limit = try parseInteger()
            if try attempt(token: .keyword("OFFSET")) {
                let offset = try parseInteger()
                algebra = .slice(algebra, offset, limit)
            } else {
                algebra = .slice(algebra, nil, limit)
            }
        } else if try attempt(token: .keyword("OFFSET")) {
            let offset = try parseInteger()
            if try attempt(token: .keyword("LIMIT")) {
                let limit = try parseInteger()
                algebra = .slice(algebra, offset, limit)
            } else {
                algebra = .slice(algebra, offset, nil)
            }
        }
        return algebra
    }
    
    private func addAggregationExtension(to algebra: Algebra, expression: Expression, variableName: String) -> Algebra {
        if case .node(.variable(let name, _)) = expression {
            if case .aggregate(_) = algebra {
                return algebra.renameAggregateVariable(from: name, to: variableName)
            }
        }
        return .extend(algebra, expression, variableName)
    }
    
    private mutating func parseValuesClause() throws -> Algebra? {
        if try attempt(token: .keyword("VALUES")) {
            return try parseDataBlock()
        }
        return nil
    }
    
    //    private mutating func parseQuads() throws -> [QuadPattern] { fatalError }
    //    private mutating func triplesByParsingTriplesTemplate() throws -> [TriplePattern] { fatalError }
    
    private mutating func parseGroupGraphPatternSub() throws -> Algebra {
        var ok = true
        var allowTriplesBlock = true
        var patterns = [UnfinishedAlgebra]()
        var filters = [UnfinishedAlgebra]()
        
        while ok {
            let t = try peekExpectedToken()
            if t.isTermOrVar {
                if !allowTriplesBlock {
                    break
                }
                let algebras = try triplesByParsingTriplesBlock()
                allowTriplesBlock = false
                patterns.append(contentsOf: algebras.map { .finished($0) })
            } else {
                switch t {
                case .lparen, .lbracket, ._var, .iri(_), .anon, .prefixname(_, _), .bnode(_), .string1d(_), .string1s(_), .string3d(_), .string3s(_), .boolean(_), .double(_), .decimal(_), .integer(_):
                    if !allowTriplesBlock {
                        break
                    }
                    let algebras = try triplesByParsingTriplesBlock()
                    allowTriplesBlock = false
                    patterns.append(contentsOf: algebras.map { .finished($0) })
                case .lbrace, .keyword(_):
                    guard let unfinished = try treeByParsingGraphPatternNotTriples() else {
                        throw parseError("Could not parse GraphPatternNotTriples in GroupGraphPatternSub (near \(t))")
                    }
                    
                    if case .filter(_) = unfinished {
                        filters.append(unfinished)
                    } else {
                        patterns.append(unfinished)
                    }
                    allowTriplesBlock = true
                    try attempt(token: .dot)
                default:
                    ok = false
                }
            }
        }

        var args = [Algebra]()
        var currentBlockSeenLabels = Set<String>()
        for pattern in patterns {
            switch pattern {
            case .finished(let algebra):
                if algebra.adjacentBlankNodeUseOK {
                    currentBlockSeenLabels.formUnion(algebra.blankNodeLabels)
                } else {
                    try guardBlankNodeResuse(with: currentBlockSeenLabels)
                    currentBlockSeenLabels = Set()
                }
                args.append(algebra)
            default:
                try guardBlankNodeResuse(with: currentBlockSeenLabels)
                currentBlockSeenLabels = Set()
                let algebra = try pattern.finish(&args)
                args.append(algebra)
            }
        }

        try guardBlankNodeResuse(with: currentBlockSeenLabels)

        for f in filters {
            let algebra = try f.finish(&args)
            args.append(algebra)
        }
        
        var algebra = args.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
        
        func replaceBlankNode(_ n: Node) -> Node? {
            switch n {
            case .bound(let term) where term.type == .blank:
                return .variable(".blank.\(term.value)", binding: false)
            default:
                return nil
            }
        }
        
        if self.parseBlankNodesAsVariables {
            algebra = try algebra.replace { (a) -> Algebra? in
                switch a {
                case .bgp(let triples):
                    if let newTriples = try? triples.map({ (t) in return try t.replace(replaceBlankNode) }) {
                        return .bgp(newTriples)
                    } else {
                        return nil
                    }
                case .quad(let q):
                    if let qp = try? q.replace(replaceBlankNode) {
                        return .quad(qp)
                    } else {
                        return nil
                    }
                case .triple(let t):
                    if let tp = try? t.replace(replaceBlankNode) {
                        return .triple(tp)
                    } else {
                        return nil
                    }
                default:
                    return nil
                }
            }
        }
        
        return algebra
    }
    
    private mutating func guardBlankNodeResuse(with currentBlockSeenLabels: Set<String>) throws {
//        print("Ended adjacent BGP block with blank node labels: \(currentBlockSeenLabels)")
        let sharedLabels = currentBlockSeenLabels.intersection(seenBlankNodeLabels)
        if sharedLabels.count > 0 {
            throw SPARQLSyntaxError.parsingError("Blank node labels cannot be used in multiple BGPs: \(sharedLabels.joined(separator: ", "))\n\(self)")
        }
        self.seenBlankNodeLabels.formUnion(currentBlockSeenLabels)
    }
    
    private mutating func parseBind() throws -> UnfinishedAlgebra {
        try expect(token: .keyword("BIND"))
        try expect(token: .lparen)
        let expr = try parseNonAggregatingExpression()
        try expect(token: .keyword("AS"))
        let node = try parseVar()
        try expect(token: .rparen)
        guard case .variable(let name, binding: _) = node else {
            throw parseError("Expecting BIND variable but got \(node)")
        }
        return .bind(expr, name)
    }
    
    private mutating func parseInlineData() throws -> Algebra {
        try expect(token: .keyword("VALUES"))
        return try parseDataBlock()
    }
    
    //[62]      DataBlock      ::=      InlineDataOneVar | InlineDataFull
    //[63]      InlineDataOneVar      ::=      Var '{' DataBlockValue* '}'
    //[64]      InlineDataFull      ::=      ( NIL | '(' Var* ')' ) '{' ( '(' DataBlockValue* ')' | NIL )* '}'
    private mutating func parseDataBlock() throws -> Algebra {
        var t = try peekExpectedToken()
        if case ._var(_) = t {
            let node = try parseVar()
            guard case .variable(_, binding: _) = node else {
                throw parseError("Expecting variable but got \(node)")
            }
            try expect(token: .lbrace)
            let values = try parseDataBlockValues()
            try expect(token: .rbrace)
            
            let results = values.map { [$0] }
            return .table([node], results)
        } else {
            var vars = [Node]()
            var names = [String]()
            if case ._nil = t {
                try expect(token: t)
            } else {
                try expect(token: .lparen)
                t = try peekExpectedToken()
                while case ._var(let name) = t {
                    try expect(token: t)
                    vars.append(.variable(name, binding: true))
                    names.append(name)
                    t = try peekExpectedToken()
                }
                try expect(token: .rparen)
            }
            try expect(token: .lbrace)
            var results = [[Term?]]()
            
            while try peek(token: .lparen) || peek(token: ._nil) {
                if try attempt(token: .lparen) {
                    let values = try parseDataBlockValues()
                    try expect(token: .rparen)
                    results.append(values)
                } else {
                    try expect(token: ._nil)
                }
            }
            try expect(token: .rbrace)
            return .table(vars, results)
        }
    }
    
    //[65]      DataBlockValue      ::=      iri |    RDFLiteral |    NumericLiteral |    BooleanLiteral |    'UNDEF'
    private mutating func parseDataBlockValues() throws -> [Term?] {
        var t = try peekExpectedToken()
        var values = [Term?]()
        while t == .keyword("UNDEF") || t.isTerm {
            if try attempt(token: .keyword("UNDEF")) {
                values.append(nil)
            } else {
                t = try nextExpectedToken()
                let node = try tokenAsTerm(t)
                guard case .bound(let term) = node else {
                    throw parseError("Expecting term but got \(node)")
                }
                guard term.type != .blank else {
                    throw parseError("Blank nodes cannot appear in VALUES blocks")
                }
                values.append(term)
            }
            t = try peekExpectedToken()
        }
        return values
    }
    
    private mutating func parseTriplesSameSubject() throws -> [TriplePattern] {
        let t = try peekExpectedToken()
        if t.isTermOrVar {
            let subj = try parseVarOrTerm()
            return try parsePropertyListNotEmpty(for: subj)
        } else if t == .lparen || t == .lbracket {
            let (subj, triples) = try parseTriplesNodeAsNode()
            let more = try parsePropertyList(subject: subj)
            return triples + more
        } else {
            return []
        }
    }
    
    private mutating func parsePropertyList(subject: Node) throws -> [TriplePattern] {
        let t = try peekExpectedToken()
        guard t.isVerb else { return [] }
        return try parsePropertyListNotEmpty(for: subject)
    }
    
    private mutating func parsePropertyListNotEmpty(for subject: Node) throws -> [TriplePattern] {
        let algebras = try parsePropertyListPathNotEmpty(for: subject)
        var triples = [TriplePattern]()
        for algebra in algebras {
            switch simplifyPath(algebra) {
            case .triple(let tp):
                triples.append(tp)
            case .bgp(let tps):
                triples.append(contentsOf: tps)
            default:
                throw parseError("Expected triple pattern but found \(algebra)")
            }
        }
        return triples
    }
    
    private mutating func triplesArrayByParsingTriplesSameSubjectPath() throws -> [Algebra] {
        let t = try peekExpectedToken()
        if t.isTermOrVar {
            let subject = try parseVarOrTerm()
            let propertyObjectTriples = try parsePropertyListPathNotEmpty(for: subject)
            // NOTE: in the original code, propertyObjectTriples could be nil here. not sure why this changed, but haven't found cases where this new code is wrong...
            return propertyObjectTriples
        } else {
            var triples = [Algebra]()
            let (subject, nodeTriples) = try parseTriplesNodePathAsNode()
            triples.append(contentsOf: nodeTriples)
            let propertyObjectTriples = try parsePropertyListPath(for: subject)
            triples.append(contentsOf: propertyObjectTriples)
            return triples
        }
    }
    
    private mutating func parseExpressionList() throws -> [Expression] {
        let t = try peekExpectedToken()
        if case ._nil = t {
            try expect(token: t)
            return []
        } else {
            try expect(token: .lparen)
            let expr = try parseExpression()
            var exprs = [expr]
            while try attempt(token: .comma) {
                let expr = try parseExpression()
                exprs.append(expr)
            }
            try expect(token: .rparen)
            return exprs
        }
    }
    
    private mutating func parsePropertyListPath(for subject: Node) throws -> [Algebra] {
        let t = try peekExpectedToken()
        guard t.isVerb else { return [] }
        return try parsePropertyListPathNotEmpty(for: subject)
    }
    
    private mutating func parsePropertyListPathNotEmpty(for subject: Node) throws -> [Algebra] {
        var t = try peekExpectedToken()
        var verb: PropertyPath? = nil
        var varpred: Node? = nil
        if case ._var(_) = t {
            varpred = try parseVerbSimple()
        } else {
            verb = try parseVerbPath()
        }
        
        let (objectList, triples) = try parseObjectListPathAsNodes()
        var propertyObjects = triples
        for o in objectList {
            if let verb = verb {
                propertyObjects.append(.path(subject, verb, o))
            } else {
                propertyObjects.append(.triple(TriplePattern(subject: subject, predicate: varpred!, object: o)))
            }
        }
        
        // push paths to the end
        propertyObjects.sort { (l, r) in if case .path(_) = l { return false } else { return true } }
//        let algebra: Algebra = propertyObjects.reduce(.joinIdentity, joinReduction(coalesceBGPs: true))
//        propertyObjects = [algebra]
        
        
        LOOP: while try attempt(token: .semicolon) {
            t = try peekExpectedToken()
            var verb: PropertyPath? = nil
            var varpred: Node? = nil
            switch t {
            case ._var(_):
                varpred = try parseVerbSimple()
            case .keyword("A"), .lparen, .hat, .bang, .iri(_), .prefixname(_, _):
                verb = try parseVerbPath()
            default:
                break LOOP
            }
            
            let (objectList, triples) = try parseObjectListPathAsNodes()
            propertyObjects.append(contentsOf: triples)
            for o in objectList {
                if let verb = verb {
                    propertyObjects.append(.path(subject, verb, o))
                } else {
                    propertyObjects.append(.triple(TriplePattern(subject: subject, predicate: varpred!, object: o)))
                }
            }
        }
        
        return propertyObjects
    }
    
    private mutating func parseVerbPath() throws -> PropertyPath {
        return try parsePath()
    }
    
    private mutating func parseVerbSimple() throws -> Node {
        return try parseVar()
    }
    
    private mutating func parseObjectListPathAsNodes() throws -> ([Node], [Algebra]) {
        var (node, triples) = try parseObjectPathAsNode()
        var objects = [node]
        
        while try attempt(token: .comma) {
            let (node, moretriples) = try parseObjectPathAsNode()
            triples.append(contentsOf: moretriples)
            objects.append(node)
        }
        
        return (objects, triples)
    }
    
    private mutating func parsePath() throws -> PropertyPath {
        return try parsePathAlternative()
    }
    
    private mutating func parsePathAlternative() throws -> PropertyPath {
        var path = try parsePathSequence()
        while try attempt(token: .or) {
            let alt = try parsePathSequence()
            path = .alt(path, alt)
        }
        return path
    }
    
    private mutating func parsePathSequence() throws -> PropertyPath {
        var path = try parsePathEltOrInverse()
        while try attempt(token: .slash) {
            let seq = try parsePathEltOrInverse()
            path = .seq(path, seq)
        }
        return path
    }
    
    private mutating func parsePathElt() throws -> PropertyPath {
        let elt = try parsePathPrimary()
        if try attempt(token: .question) {
            return .zeroOrOne(elt)
        } else if try attempt(token: .star) {
            return .star(elt)
        } else if try attempt(token: .plus) {
            return .plus(elt)
        } else {
            return elt
        }
    }
    
    private mutating func parsePathEltOrInverse() throws -> PropertyPath {
        if try attempt(token: .hat) {
            let path = try parsePathElt()
            return .inv(path)
        } else {
            return try parsePathElt()
        }
    }
    
    private mutating func parsePathPrimary() throws -> PropertyPath {
        if try attempt(token: .lparen) {
            let path = try parsePath()
            try expect(token: .rparen)
            return path
        } else if try attempt(token: .keyword("A")) {
            let term = Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri)
            return .link(term)
        } else if try attempt(token: .bang) {
            return try parsePathNegatedPropertySet()
        } else {
            let term = try parseIRI()
            return .link(term)
        }
    }
    private mutating func parsePathNegatedPropertySet() throws -> PropertyPath {
        if try attempt(token: .lparen) {
            let path = try parsePathOneInPropertySet()
            guard case .link(let iri) = path else {
                throw parseError("Expected NPS IRI but found \(path)")
            }
            var iris = [iri]
            while try attempt(token: .or) {
                let rhs = try parsePathOneInPropertySet()
                guard case .link(let iri) = rhs else {
                    throw parseError("Expected NPS IRI but found \(path)")
                }
                iris.append(iri)
            }
            try expect(token: .rparen)
            return .nps(iris)
        } else {
            let path = try parsePathOneInPropertySet()
            guard case .link(let iri) = path else {
                throw parseError("Expected NPS IRI but found \(path)")
            }
            return .nps([iri])
        }
    }
    
    private mutating func parsePathOneInPropertySet() throws -> PropertyPath {
        let t = try peekExpectedToken()
        if t == .hat {
            switch t {
            case .keyword("A"):
                return .inv(.link(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri)))
            default:
                let iri = try parseIRI()
                return .inv(.link(iri))
            }
        } else if case .keyword("A") = t {
            return .link(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        } else {
            let iri = try parseIRI()
            return .link(iri)
        }
        /**
         
         SPKSPARQLToken* t   = [self peekNextNonCommentToken];
         if (t.type == HAT) {
         [self nextNonCommentToken];
         t   = [self peekNextNonCommentToken];
         if (t.type == KEYWORD && [t.value isEqualToString: @"A"]) {
         [self nextNonCommentToken];
         id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
         id<SPKTree> path    = [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
         return [[SPKTree alloc] initWithType:kPathInverse arguments:@[path]];
         } else {
         id<SPKTree> path    = [self parseIRIWithErrors: errors];
         return [[SPKTree alloc] initWithType:kPathInverse arguments:@[path]];
         }
         } else if (t.type == KEYWORD && [t.value isEqualToString: @"A"]) {
         [self nextNonCommentToken];
         id<GTWTerm> term    = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
         return [[SPKTree alloc] initWithType:kTreeNode value: term arguments:nil];
         } else if (t.type == NIL) {
         return [self errorMessage:@"Expecting IRI but found NIL" withErrors:errors];
         } else {
         return [self parseIRIWithErrors: errors];
         }
         
         
         **/
    }
    
    private mutating func parseObjectPathAsNode() throws -> (Node, [Algebra]) {
        return try parseGraphNodePathAsNode()
    }
    
    private mutating func parseTriplesNodeAsNode() throws -> (Node, [TriplePattern]) {
        if try peek(token: .lparen) {
            return try triplesByParsingCollectionAsNode()
        } else {
            return try parseBlankNodePropertyListAsNode()
        }
    }
    
    private mutating func parseBlankNodePropertyListAsNode() throws -> (Node, [TriplePattern]) {
        let (node, patterns) = try parseBlankNodePropertyListPathAsNode()
        var triples = [TriplePattern]()
        for p in patterns {
            switch simplifyPath(p) {
            case .triple(let t):
                triples.append(t)
            case .bgp(let ts):
                triples.append(contentsOf: ts)
            default:
                throw parseError("Unexpected template triple: \(p)")
            }
        }
        return (node, triples)
    }
    
    private mutating func parseTriplesNodePathAsNode() throws -> (Node, [Algebra]) {
        if try peek(token: .lparen) {
            return try triplesByParsingCollectionPathAsNode()
        } else {
            return try parseBlankNodePropertyListPathAsNode()
        }
    }
    
    private mutating func parseBlankNodePropertyListPathAsNode() throws -> (Node, [Algebra]) {
        try expect(token: .lbracket)
        let node: Node = bnode()
        let path = try parsePropertyListPathNotEmpty(for: node)
        try expect(token: .rbracket)
        return (node, path)
    }
    
    private mutating func triplesByParsingCollectionAsNode() throws -> (Node, [TriplePattern]) {
        let (node, patterns) = try triplesByParsingCollectionPathAsNode()
        var triples = [TriplePattern]()
        for p in patterns {
            switch p {
            case .triple(let t):
                triples.append(t)
            case .bgp(let ts):
                triples.append(contentsOf: ts)
            default:
                throw parseError("Unexpected template triple: \(p)")
            }
        }
        return (node, triples)
    }
    
    private mutating func triplesByParsingCollectionPathAsNode() throws -> (Node, [Algebra]) {
        try expect(token: .lparen)
        let (node, graphNodePath) = try parseGraphNodePathAsNode()
        var triples = graphNodePath
        var nodes = [node]
        while try !peek(token: .rparen) {
            let (node, graphNodePath) = try parseGraphNodePathAsNode()
            triples.append(contentsOf: graphNodePath)
            nodes.append(node)
        }
        try expect(token: .rparen)
        
        let bnode = self.bnode()
        var list = bnode
        
        let rdffirst = Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#first", type: .iri)
        let rdfrest = Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest", type: .iri)
        let rdfnil = Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil", type: .iri)
        
        var patterns = [TriplePattern]()
        if nodes.count > 0 {
            for (i, o) in nodes.enumerated() {
                let triple = TriplePattern(subject: list, predicate: .bound(rdffirst), object: o)
                patterns.append(triple)
                if i == (nodes.count-1) {
                    let triple = TriplePattern(subject: list, predicate: .bound(rdfrest), object: .bound(rdfnil))
                    patterns.append(triple)
                } else {
                    let newlist = self.bnode()
                    let triple = TriplePattern(subject: list, predicate: .bound(rdfrest), object: newlist)
                    patterns.append(triple)
                    list = newlist
                }
            }
            triples.append(.bgp(patterns))
        } else {
            let triple = TriplePattern(subject: list, predicate: .bound(rdffirst), object: .bound(rdfnil))
            triples.append(.bgp([triple]))
        }
        return (bnode, triples)
    }
    
    //    private mutating func parseGraphNodeAsNode() throws -> (Node, [Algebra]) { fatalError }
    
    private mutating func parseGraphNodePathAsNode() throws -> (Node, [Algebra]) {
        let t = try peekExpectedToken()
        if t.isTermOrVar {
            let node = try parseVarOrTerm()
            return (node, [])
        } else {
            return try parseTriplesNodePathAsNode()
        }
    }
    
    private mutating func parseVarOrTerm() throws -> Node {
        let t = try nextExpectedToken()
        return try tokenAsTerm(t)
    }
    
    private mutating func parseVarOrIRI() throws -> Node {
        let node = try parseVarOrTerm()
        if case .variable(_) = node {
        } else if case .bound(let term) = node, term.type == .iri {
        } else {
            throw parseError("Expected variable but found \(node)")
        }
        return node
    }
    
    private mutating func parseVar() throws -> Node {
        let t = try nextExpectedToken()
        let node = try tokenAsTerm(t)
        guard case .variable(_) = node else {
            throw parseError("Expected variable but found \(node)")
        }
        return node
    }
    
    private mutating func parseNonAggregatingExpression() throws -> Expression {
        let expr = try parseExpression()
        guard !expr.hasAggregation else {
            throw parseError("Unexpected aggregation in BIND expression")
        }
        return expr
    }
    
    private mutating func parseExpression() throws -> Expression {
        return try parseConditionalOrExpression()
    }
    
    private mutating func parseConditionalOrExpression() throws -> Expression {
        var expr = try parseConditionalAndExpression()
        while try attempt(token: .oror) {
            let rhs = try parseConditionalAndExpression()
            expr = .or(expr, rhs)
        }
        return expr
    }
    
    private mutating func parseConditionalAndExpression() throws -> Expression {
        var expr = try parseValueLogical()
        while try attempt(token: .andand) {
            let rhs = try parseValueLogical()
            expr = .and(expr, rhs)
        }
        return expr
    }
    
    private mutating func parseValueLogical() throws -> Expression {
        return try parseRelationalExpression()
    }
    
    private mutating func parseRelationalExpression() throws -> Expression {
        let expr = try parseNumericExpression()
        let t = try peekExpectedToken()
        switch t {
        case .equals, .notequals, .lt, .gt, .le, .ge:
            nextToken()
            let rhs = try parseNumericExpression()
            if t == .equals {
                return .eq(expr, rhs)
            } else if t == .notequals {
                return .ne(expr, rhs)
            } else if t == .lt {
                return .lt(expr, rhs)
            } else if t == .gt {
                return .gt(expr, rhs)
            } else if t == .le {
                return .le(expr, rhs)
            } else {
                return .ge(expr, rhs)
            }
        case .keyword("IN"):
            nextToken()
            let exprs = try parseExpressionList()
            return .valuein(expr, exprs)
        case .keyword("NOT"):
            nextToken()
            try expect(token: .keyword("IN"))
            let exprs = try parseExpressionList()
            return .not(.valuein(expr, exprs))
        default:
            return expr
        }
        /**
         id<SPKTree> expr    = [self parseNumericExpressionWithErrors:errors];
         SPKSPARQLToken* t   = [self peekNextNonCommentToken];
         if (t && (t.type == EQUALS || t.type == NOTEQUALS || t.type == LT || t.type == GT || t.type == LE || t.type == GE)) {
         [self nextNonCommentToken];
         id<SPKTree> rhs  = [self parseNumericExpressionWithErrors:errors];
         ASSERT_EMPTY(errors);
         SPKTreeType type;
         switch (t.type) {
         case EQUALS:
         type    = kExprEq;
         break;
         case NOTEQUALS:
         type    = kExprNeq;
         break;
         case LT:
         type    = kExprLt;
         break;
         case GT:
         type    = kExprGt;
         break;
         case LE:
         type    = kExprLe;
         break;
         case GE:
         type    = kExprGe;
         break;
         default:
         return nil;
         }
         if (!(expr && rhs)) {
         return [self errorMessage:@"Failed to parse relational expression" withErrors:errors];
         }
         expr    = [[SPKTree alloc] initWithType:type arguments:@[expr, rhs]];
         } else if (t && t.type == KEYWORD && [t.value isEqualToString: @"IN"]) {
         [self nextNonCommentToken];
         id<SPKTree> list    = [self parseExpressionListWithErrors: errors];
         ASSERT_EMPTY(errors);
         return [[SPKTree alloc] initWithType:kExprIn arguments:@[expr, list]];
         } else if (t && t.type == KEYWORD && [t.value isEqualToString: @"NOT"]) {
         [self nextNonCommentToken];
         [self parseExpectedTokenOfType:KEYWORD withValue:@"IN" withErrors:errors];
         ASSERT_EMPTY(errors);
         id<SPKTree> list    = [self parseExpressionListWithErrors: errors];
         ASSERT_EMPTY(errors);
         return [[SPKTree alloc] initWithType:kExprNotIn arguments:@[expr, list]];
         }
         return expr;
         
         **/
    }
    
    private mutating func parseNumericExpression() throws -> Expression {
        return try parseAdditiveExpression()
    }
    
    private mutating func parseAdditiveExpression() throws -> Expression {
        var expr = try parseMultiplicativeExpression()
        var t = try peekExpectedToken()
        while t == .plus || t == .minus {
            try expect(token: t)
            let rhs = try parseMultiplicativeExpression()
            if t == .plus {
                expr = .add(expr, rhs)
            } else {
                expr = .sub(expr, rhs)
            }
            t = try peekExpectedToken()
        }
        return expr
    }
    
    private mutating func parseMultiplicativeExpression() throws -> Expression {
        var expr = try parseUnaryExpression()
        var t = try peekExpectedToken()
        while t == .star || t == .slash {
            try expect(token: t)
            let rhs = try parseUnaryExpression()
            if t == .star {
                expr = .mul(expr, rhs)
            } else {
                expr = .div(expr, rhs)
            }
            t = try peekExpectedToken()
        }
        return expr
    }
    
    private mutating func parseUnaryExpression() throws -> Expression {
        if try attempt(token: .bang) {
            let expr = try parsePrimaryExpression()
            return .not(expr)
        } else if try attempt(token: .plus) {
            let expr = try parsePrimaryExpression()
            return expr
        } else if try attempt(token: .minus) {
            let expr = try parsePrimaryExpression()
            if case .node(.bound(let term)) = expr, term.isNumeric, let value = term.numeric {
                let neg = .integer(0) - value
                return .node(.bound(neg.term))
            }
            return .neg(expr)
        } else {
            let expr = try parsePrimaryExpression()
            return expr
        }
    }
    
    private mutating func parsePrimaryExpression() throws -> Expression {
        if try peek(token: .lparen) {
            return try parseBrackettedExpression()
        } else {
            let t = try peekExpectedToken()
            switch t {
            case .iri(_), .prefixname(_, _):
                return try parseIRIOrFunction()
            case ._nil, .anon, .bnode(_):
                throw parseError("Expected PrimaryExpression term (IRI, Literal, or Var) but found \(t)")
            case _ where t.isTermOrVar:
                return try .node(parseVarOrTerm())
            default:
                let expr = try parseBuiltInCall()
                return expr
            }
        }
    }
    
    private mutating func parseIRIOrFunction() throws -> Expression {
        let iri = try parseIRI()
        if try attempt(token: ._nil) {
            return convertCallToExpression(e: .call(iri.value, []))
        } else if try attempt(token: .lparen) {
            if try attempt(token: .rparen) {
                return convertCallToExpression(e: .call(iri.value, []))
            } else {
                try attempt(token: .keyword("DISTINCT"))
                let expr = try parseExpression()
                var args = [expr]
                while try attempt(token: .comma) {
                    let expr = try parseExpression()
                    args.append(expr)
                }
                try expect(token: .rparen)
                return convertCallToExpression(e: .call(iri.value, args))
            }
        } else {
            return .node(.bound(iri))
        }
    }
    
    private mutating func parseBrackettedExpression() throws -> Expression {
        try expect(token: .lparen)
        let expr = try parseExpression()
        try expect(token: .rparen)
        return expr
    }
    
    private func convertCallToExpression(e: Expression) -> Expression {
        // These are the built-in functions that are currently represented
        // with .call that lack individual representations in Expression:
        //    "ABS"
        //    "BNODE"
        //    "CEIL"
        //    "COALESCE"
        //    "CONCAT"
        //    "CONTAINS"
        //    "DAY"
        //    "ENCODE_FOR_URI"
        //    "FLOOR"
        //    "HOURS"
        //    "IF"
        //    "IRI"
        //    "LCASE"
        //    "MD5"
        //    "MINUTES"
        //    "MONTH"
        //    "NOW"
        //    "RAND"
        //    "REGEX"
        //    "REPLACE"
        //    "ROUND"
        //    "SECONDS"
        //    "SHA1"
        //    "SHA256"
        //    "SHA384"
        //    "SHA512"
        //    "STR",
        //    "STRAFTER"
        //    "STRBEFORE"
        //    "STRDT"
        //    "STRENDS"
        //    "STRLANG"
        //    "STRLEN"
        //    "STRSTARTS"
        //    "STRUUID"
        //    "SUBSTR"
        //    "TIMEZONE"
        //    "TZ"
        //    "UCASE"
        //    "URI"
        //    "UUID"
        //    "YEAR"
        
        switch e {
        case let .call("BOUND", exprs):
            return .bound(exprs[0])
        case let .call("DATATYPE", exprs):
            return .datatype(exprs[0])
        case let .call("SAMETERM", exprs):
            return .sameterm(exprs[0], exprs[1])
        case let .call("LANG", exprs):
            return .lang(exprs[0])
        case let .call("LANGMATCHES", exprs):
            return .langmatches(exprs[0], exprs[1])
        case let .call("ISNUMERIC", exprs):
            return .isnumeric(exprs[0])
        case let .call("ISIRI", exprs), let .call("ISURI", exprs):
            return .isiri(exprs[0])
        case let .call("ISLITERAL", exprs):
            return .isliteral(exprs[0])
        case let .call("ISBLANK", exprs):
            return .isblank(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#boolean", exprs):
            return .boolCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#integer", exprs):
            return .intCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#double", exprs):
            return .doubleCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#float", exprs):
            return .floatCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#decimal", exprs):
            return .decimalCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#dateTime", exprs):
            return .dateTimeCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#date", exprs):
            return .dateCast(exprs[0])
        case let .call("http://www.w3.org/2001/XMLSchema#string", exprs):
            return .stringCast(exprs[0])
        default:
            return e
        }
    }
    
    private mutating func parseBuiltInCall() throws -> Expression {
        let t = try peekExpectedToken()
        switch t {
        case .keyword(let kw) where SPARQLLexer.validAggregations.contains(kw):
            let agg = try parseAggregate()
            return .aggregate(agg)
        case .keyword("NOT"):
            try expect(token: t)
            try expect(token: .keyword("EXISTS"))
            let ggp = try parseGroupGraphPattern()
            return .not(.exists(ggp))
        case .keyword("EXISTS"):
            try expect(token: t)
            let ggp = try parseGroupGraphPattern()
            return .exists(ggp)
        case .keyword(let kw) where SPARQLLexer.validFunctionNames.contains(kw):
            try expect(token: t)
            var args = [Expression]()
            if try !attempt(token: ._nil) {
                try expect(token: .lparen)
                let expr = try parseExpression()
                args.append(expr)
                while try attempt(token: .comma) {
                    let expr = try parseExpression()
                    args.append(expr)
                }
                try expect(token: .rparen)
            }
            return convertCallToExpression(e: .call(kw, args))
        default:
            throw parseError("Expected built-in function call but found \(t)")
        }
    }
    
    private mutating func parseAggregate() throws -> Aggregation {
        let t = try nextExpectedToken()
        guard case .keyword(let name) = t else {
            throw parseError("Expected aggregate name but found \(t)")
        }
        
        switch name {
        case "COUNT":
            try expect(token: .lparen)
            let distinct = try attempt(token: .keyword("DISTINCT"))
            let agg: Aggregation
            if try attempt(token: .star) {
                agg = .countAll
            } else {
                let expr = try parseNonAggregatingExpression()
                agg = .count(expr, distinct)
            }
            try expect(token: .rparen)
            return agg
        case "SUM":
            try expect(token: .lparen)
            let distinct = try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            let agg: Aggregation = .sum(expr, distinct)
            try expect(token: .rparen)
            return agg
        case "MIN":
            try expect(token: .lparen)
            let _ = try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            let agg: Aggregation = .min(expr)
            try expect(token: .rparen)
            return agg
        case "MAX":
            try expect(token: .lparen)
            let _ = try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            let agg: Aggregation = .max(expr)
            try expect(token: .rparen)
            return agg
        case "AVG":
            try expect(token: .lparen)
            let distinct = try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            let agg: Aggregation = .avg(expr, distinct)
            try expect(token: .rparen)
            return agg
        case "SAMPLE":
            try expect(token: .lparen)
            try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            let agg: Aggregation = .sample(expr)
            try expect(token: .rparen)
            return agg
        case "GROUP_CONCAT":
            try expect(token: .lparen)
            let distinct = try attempt(token: .keyword("DISTINCT"))
            let expr = try parseNonAggregatingExpression()
            
            var sep = " "
            if try attempt(token: .semicolon) {
                try expect(token: .keyword("SEPARATOR"))
                try expect(token: .equals)
                let t = try nextExpectedToken()
                let node = try tokenAsTerm(t)
                guard case .bound(let term) = node, case .datatype("http://www.w3.org/2001/XMLSchema#string") = term.type else {
                    throw parseError("Expected GROUP_CONCAT SEPARATOR but found \(node)")
                }
                sep = term.value
            }
            let agg: Aggregation = .groupConcat(expr, sep, distinct)
            try expect(token: .rparen)
            return agg
        default:
            throw parseError("Unrecognized aggregate name '\(name)'")
        }
        /**
         
         SPKSPARQLToken* t   = [self parseExpectedTokenOfType:KEYWORD withErrors:errors];
         ASSERT_EMPTY(errors);
         } else if ([t.value isEqualToString: @"GROUP_CONCAT"]) {
         [self parseExpectedTokenOfType:LPAREN withErrors:errors];
         ASSERT_EMPTY(errors);
         SPKSPARQLToken* d   = [self parseOptionalTokenOfType:KEYWORD withValue:@"DISTINCT"];
         id<SPKTree> expr    = [self parseExpressionWithErrors:errors];
         ASSERT_EMPTY(errors);
         
         SPKSPARQLToken* sc  = [self parseOptionalTokenOfType:SEMICOLON];
         NSString* separator = @" ";
         if (sc) {
         [self parseExpectedTokenOfType:KEYWORD withValue:@"SEPARATOR" withErrors:errors];
         ASSERT_EMPTY(errors);
         [self parseExpectedTokenOfType:EQUALS withErrors:errors];
         ASSERT_EMPTY(errors);
         SPKSPARQLToken* t   = [self nextNonCommentToken];
         id<GTWTerm> str     = [self tokenAsTerm:t withErrors:errors];
         ASSERT_EMPTY(errors);
         
         separator   = str.value;
         }
         id<SPKTree> agg     = [[SPKTree alloc] initWithType:kExprGroupConcat value: @[@(d ? YES: NO), separator] arguments:@[expr]];
         [self parseExpectedTokenOfType:RPAREN withErrors:errors];
         ASSERT_EMPTY(errors);
         [self addSeenAggregate:agg];
         return agg;
         }
         
         **/
        
    }
    
    private mutating func parseIRI() throws -> Term {
        let t = try nextExpectedToken()
        let node = try tokenAsTerm(t)
        guard case .bound(let term) = node, case .iri = term.type else {
            throw parseError("Bad path IRI: \(node)")
        }
        return term
    }
    
    private mutating func triplesByParsingTriplesBlock() throws -> [Algebra] {
        var sameSubj = try triplesArrayByParsingTriplesSameSubjectPath()
        let t = peekToken()
        if t == .none || t != .some(.dot) {
            
        } else {
            try expect(token: .dot)
            let t = try peekExpectedToken()
            if t.isTermOrVar {
                let more = try triplesByParsingTriplesBlock()
                sameSubj += more
            }
        }
        
        return Array(sameSubj.map { simplifyPath($0) })
    }
    
    private func simplifyPath(_ algebra: Algebra) -> Algebra {
        guard case .path(let s, .link(let iri), let o) = algebra else { return algebra }
        let node: Node = .bound(iri)
        let triple = TriplePattern(subject: s, predicate: node, object: o)
        return .triple(triple)
    }
    
    private mutating func treeByParsingGraphPatternNotTriples() throws -> UnfinishedAlgebra? {
        let t = try peekExpectedToken()
        if case .keyword("OPTIONAL") = t {
            try expect(token: t)
            let ggp = try parseGroupGraphPattern()
            return .optional(ggp)
        } else if case .keyword("MINUS") = t {
            try expect(token: t)
            let ggp = try parseGroupGraphPattern()
            return .minus(ggp)
        } else if case .keyword("GRAPH") = t {
            try expect(token: t)
            let node = try parseVarOrIRI()
            let ggp = try parseGroupGraphPattern()
            return .finished(.namedGraph(ggp, node))
        } else if case.keyword("SERVICE") = t {
            try expect(token: t)
            let silent = try attempt(token: .keyword("SILENT"))
            let node = try parseVarOrIRI()
            guard case .bound(let endpoint) = node else {
                throw parseError("Expecting IRI as SERVICE endpoint but got \(node)")
            }
            let ggp = try parseGroupGraphPattern()
            guard let url = URL(string: endpoint.value) else {
                throw parseError("Endpoint IRI is an invalid URL: \(endpoint.value)")
            }
            
            return .finished(.service(url, ggp, silent))
        } else if case .keyword("FILTER") = t {
            try expect(token: t)
            let expression = try parseConstraint()
            return .filter(expression)
        } else if case .keyword("VALUES") = t {
            let data = try parseInlineData()
            return .finished(data)
        } else if case .keyword("BIND") = t {
            return try parseBind()
        } else if case .keyword(_) = t {
            throw parseError("Expecting KEYWORD but got \(t)")
        } else if case .lbrace = t {
            var ggp = try parseGroupGraphPattern()
            while try attempt(token: .keyword("UNION")) {
                let rhs = try parseGroupGraphPattern()
                ggp = .union(ggp, rhs)
            }
            return .finished(ggp)
        } else {
            let t = try peekExpectedToken()
            throw parseError("Expecting group graph pattern but got \(t)")
        }
    }
    
    private mutating func literalAsTerm(_ value: String) throws -> Node {
        if try attempt(token: .hathat) {
            let t = try nextExpectedToken()
            let dt = try tokenAsTerm(t)
            guard case .bound(let dtterm) = dt else {
                throw parseError("Expecting datatype but found '\(dt)'")
            }
            guard case .iri = dtterm.type else {
                throw parseError("Expecting datatype IRI but found '\(dtterm)'")
            }
            return .bound(Term(value: value, type: .datatype(dtterm.value)))
        } else {
            let t = try peekExpectedToken()
            if case .lang(let lang) = t {
                let _ = try nextExpectedToken()
                return .bound(Term(value: value, type: .language(lang)))
            }
        }
        return .bound(Term(value: value, type: .datatype("http://www.w3.org/2001/XMLSchema#string")))
    }
    
    private mutating func resolveIRI(value: String) throws -> Node {
        var iri = value
        if let base = base {
//            print("Attempting to resolve IRI string '\(value)' against \(base)")
            guard let b = IRI(string: base), let i = IRI(string: value, relativeTo: b) else {
                throw parseError("Failed to resolve IRI against base IRI")
            }
            iri = i.absoluteString
        }
        return .bound(Term(value: iri, type: .iri))
    }
    
    private mutating func tokenAsTerm(_ token: SPARQLToken) throws -> Node {
        switch token {
        case ._nil:
            return .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil", type: .iri))
        case ._var(let name):
            return .variable(name, binding: true)
        case .iri(let value):
            return try resolveIRI(value: value)
        case .prefixname(let pn, let ln):
            guard let ns = self.prefixes[pn] else {
                throw parseError("Use of undeclared prefix '\(pn)'")
            }
            return try resolveIRI(value: ns + ln)
        case .anon:
            return bnode()
        case .keyword("A"):
            return .bound(Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type", type: .iri))
        case .boolean(let value):
            return .bound(Term(value: value, type: .datatype("http://www.w3.org/2001/XMLSchema#boolean")))
        case .decimal(let value):
            return .bound(Term(value: value, type: .datatype("http://www.w3.org/2001/XMLSchema#decimal")))
        case .double(let value):
            return .bound(Term(value: value, type: .datatype("http://www.w3.org/2001/XMLSchema#double")))
        case .integer(let value):
            return .bound(Term(value: value, type: .datatype("http://www.w3.org/2001/XMLSchema#integer")))
        case .bnode(let name):
            let node = bnode(named: name)
            return node
        case .string1d(let value), .string1s(let value), .string3d(let value), .string3s(let value):
            return try literalAsTerm(value)
        case .plus:
            let t = try nextExpectedToken()
            return try tokenAsTerm(t)
        case .minus:
            let t = try nextExpectedToken()
            let node = try tokenAsTerm(t)
            guard case .bound(let term) = node, term.isNumeric, let value = term.numeric else {
                throw parseError("Cannot negate \(node)")
            }
            let neg = .integer(0) - value
            return .bound(neg.term)
        default:
            throw parseError("Expecting term but got \(token)")
        }
    }
    
    mutating private func parseInteger() throws -> Int {
        let l = try nextExpectedToken()
        let t = try tokenAsTerm(l)
        guard case .bound(let term) = t, case .datatype("http://www.w3.org/2001/XMLSchema#integer") = term.type else {
            throw parseError("Expecting integer but found \(t)")
        }
        guard let limit = Int(term.value) else {
            throw parseError("Failed to parse integer value from \(term)")
        }
        return limit
    }
}

enum SPARQLEscapingType {
    case literal1d
    case literal1s
    case literal3d
    case literal3s
    case iri
    case prefixedLocalName
}

extension String {
    private var commonString1Escaped: String {
        var v = self
        v = v.replacingOccurrences(of: "\\", with: "\\\\")
        v = v.replacingOccurrences(of: "\t", with: "\\r")
        v = v.replacingOccurrences(of: "\n", with: "\\r")
        v = v.replacingOccurrences(of: "\r", with: "\\r")
        v = v.replacingOccurrences(of: "\u{08}", with: "\\b")
        v = v.replacingOccurrences(of: "\u{0c}", with: "\\f")
        return v
    }
    
    private var commonString3Escaped: String {
        var v = self
        v = v.replacingOccurrences(of: "\\", with: "\\\\")
        v = v.replacingOccurrences(of: "\t", with: "\\r")
        v = v.replacingOccurrences(of: "\u{08}", with: "\\b")
        v = v.replacingOccurrences(of: "\u{0c}", with: "\\f")
        return v
    }
    
    func escape(for type: SPARQLEscapingType) -> String {
        switch type {
        case .literal1d:
            var v = self.commonString1Escaped
            v = v.replacingOccurrences(of: "\"", with: "\\\"")
            return v
        case .literal1s:
            var v = self.commonString1Escaped
            v = v.replacingOccurrences(of: "'", with: "\\'")
            return v
        case .literal3d:
            var v = self.commonString3Escaped
            v = v.replacingOccurrences(of: "\"\"\"", with: "\\\"\"\"")
            return v
        case .literal3s:
            var v = self.commonString3Escaped
            v = v.replacingOccurrences(of: "'''", with: "\\'''")
            return v
        case .iri:
            let bad = CharacterSet(charactersIn: "<>\"{}|^`\\")
            let control = CharacterSet(charactersIn: UnicodeScalar(0)...UnicodeScalar(0x20))
            if let v = self.addingPercentEncoding(withAllowedCharacters: bad.union(control).inverted) {
                return v
            } else {
                print("*** failed to escape IRI <\(self)>")
                return self
            }
        case .prefixedLocalName:
            var v = ""
            /**
             
             prefixed name first character:
             - leave untouched characters in pnCharsU, ':', or [0-9]
             - backslash escape these characters: ( '_' | '~' | '.' | '-' | '!' | '$' | '&' | "'" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%' )
             - percent encode anything else
             **/
            
            let okFirst = String.pnCharsU.union(CharacterSet(charactersIn: "0123456789:"))
            guard let first = self.first else { return "" }
            let fcs = CharacterSet(first.unicodeScalars)
            if fcs.isStrictSubset(of: okFirst) {
                v += String(first)
            } else if let escaped = String(first).sparqlBackslashEscape {
                v += escaped
            } else {
                v += String(first).sparqlPercentEncoded
            }
            
            /**
             prefixed name local part (non-first character):
             - cannot end in a '.'
             - backslash escape these characters: ( '_' | '~' | '.' | '-' | '!' | '$' | '&' | "'" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%' )
             - leave untouched characters in pnChars
             - percent encode anything else
             
             **/
            for c in self.dropFirst(1) {
                let cs = CharacterSet(c.unicodeScalars)
                if let escaped = String(c).sparqlBackslashEscape {
                    v += String(escaped)
                } else if cs.isStrictSubset(of: String.pnChars) {
                    v += String(c)
                } else {
                    v += String(c).sparqlPercentEncoded
                }
            }
            
            guard let last = v.last else { return v }
            if last == "." {
                v = String(v[..<v.endIndex])
                v += ".".sparqlPercentEncoded
            }
            
            return v
        }
    }
    
    private var sparqlPercentEncoded : String {
        var v = ""
        for u in self.utf8 {
            v += String(format: "%%%02d", u)
        }
        return v
    }
    
    private var sparqlBackslashEscape : String? {
        let needsEscaping = CharacterSet(charactersIn: "_~.-!$('()*+,;=/?#@%")
        var v = ""
        for c in self {
            let cs = CharacterSet(c.unicodeScalars)
            if cs.isStrictSubset(of: needsEscaping) {
                v += "\\"
                v += String(c)
            } else {
                v += String(c)
            }
        }
        return v
    }
    
    private static let pnChars: CharacterSet = {
        var pn = pnCharsU
        pn.insert(charactersIn: "0123456789-")
        pn.insert(UnicodeScalar(0xB7))
        
        // [#x0300-#x036F] | [#x203F-#x2040]
        let ranges: [(Int, Int)] = [
            (0x300, 0x36F),
            (0x203F, 0x2040),
            ]
        for bounds in ranges {
            guard let mn = UnicodeScalar(bounds.0) else { fatalError("Failed to construct built-in CharacterSet") }
            guard let mx = UnicodeScalar(bounds.1) else { fatalError("Failed to construct built-in CharacterSet") }
            let range = mn...mx
            pn.insert(charactersIn: range)
        }
        
        return pn
    }()
    
    private static let pnCharsU: CharacterSet = {
        var pn = CharacterSet(charactersIn: "_")
        pn.insert(charactersIn: "a"..."z")
        pn.insert(charactersIn: "A"..."Z")
        
        let ranges: [(Int, Int)] = [
            (0xC0, 0xD6),
            (0xD8, 0xF6),
            (0xF8, 0x2FF),
            (0x370, 0x37D),
            (0x37F, 0x1FFF),
            (0x200C, 0x200D),
            (0x2070, 0x218F),
            (0x2C00, 0x2FEF),
            (0x3001, 0xD7FF),
            (0xF900, 0xFDCF),
            (0xFDF0, 0xFFFD),
            (0x10000, 0xEFFFF),
            ]
        for bounds in ranges {
            guard let mn = UnicodeScalar(bounds.0) else { fatalError("Failed to construct built-in CharacterSet") }
            guard let mx = UnicodeScalar(bounds.1) else { fatalError("Failed to construct built-in CharacterSet") }
            let range = mn...mx
            pn.insert(charactersIn: range)
        }
        return pn
    }()
    
}

extension Algebra {
    internal var adjacentBlankNodeUseOK: Bool {
        switch self {
        case .triple(_), .quad(_), .bgp(_), .path(_):
            return true
        default:
            return false
        }
    }
    
    /**
     This is used internally to throw exceptions on queries that use blank node labels in more than one BGP.
     It is not entirely accurate, as we exempt property paths from returning blank node labels so that they
     do not conflict with adjacent BGPs <https://www.w3.org/2013/sparql-errata#errata-query-17>
     */
    internal var blankNodeLabels: Set<String> {
        switch self {
            
        case .joinIdentity, .unionIdentity, .table(_, _):
            return Set()
            
        case .subquery(let q):
            return q.algebra.blankNodeLabels
            
        case .filter(let child, _), .minus(let child, _), .distinct(let child), .slice(let child, _, _), .namedGraph(let child, _), .order(let child, _), .service(_, let child, _), .project(let child, _), .extend(let child, _, _), .aggregate(let child, _, _), .window(let child, _, _):
            return child.blankNodeLabels
            
            
        case .triple(let t):
            var b = Set<String>()
            for node in [t.subject, t.predicate, t.object] {
                if case .bound(let term) = node {
                    if case .blank = term.type {
                        b.insert(term.value)
                    }
                }
            }
            return b
        case .quad(let q):
            var b = Set<String>()
            for node in [q.subject, q.predicate, q.object, q.graph] {
                if case .bound(let term) = node {
                    if case .blank = term.type {
                        b.insert(term.value)
                    }
                }
            }
            return b
        case .bgp(let triples):
            if triples.count == 0 {
                return Set()
            }
            var b = Set<String>()
            for t in triples {
                for node in [t.subject, t.predicate, t.object] {
                    if case .bound(let term) = node {
                        if case .blank = term.type {
                            b.insert(term.value)
                        }
                    }
                }
            }
            return b
        case let .path(subject, _, object):
            var b = Set<String>()
            for node in [subject, object] {
                if case .bound(let term) = node {
                    if case .blank = term.type {
                        b.insert(term.value)
                    }
                }
            }
            return b
            
        case .leftOuterJoin(let lhs, let rhs, _), .innerJoin(let lhs, let rhs), .union(let lhs, let rhs):
            let l = lhs.blankNodeLabels
            let r = rhs.blankNodeLabels
            
            switch (lhs, rhs) {
            case (.bgp(_), .path(_)), (.path(_), .bgp(_)),
                 (.triple(_), .path(_)), (.path(_), .triple(_)),
                 (.quad(_), .path(_)), (.path(_), .quad(_)),
                 (.path(_), .path(_)):
                // reuse of bnode labels should be acceptable when in adjacent BGPs and property paths
                // https://www.w3.org/2013/sparql-errata#errata-query-17
                return l.union(r)
            default:
                break
            }
            return l.union(r)
        }
        
    }
}
