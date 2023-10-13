//
//  SPARQLSerialization.swift
//  kineo-test
//
//  Created by Gregory Todd Williams on 4/12/18.
//  Copyright © 2018 Gregory Todd Williams. All rights reserved.
//

import Foundation

public struct SPARQLSerializer {
    internal(set) public var prettyPrint: Bool
    
    public init(prettyPrint: Bool = false) {
        self.prettyPrint = prettyPrint
    }
    
    public func reformat(_ sparql: String) -> String {
        guard let data = sparql.data(using: .utf8) else {
            return sparql
        }
        let stream = InputStream(data: data)
        stream.open()
        let lexer: SPARQLLexer
        do {
            lexer = try SPARQLLexer(source: stream, includeComments: true)
        } catch {
            return sparql
        }
        
        var tokens = [PositionedSPARQLToken]()
        do {
            while true {
                if let pt = try lexer.getToken() {
                    tokens.append(pt)
                } else {
                    let formatted = self.serialize(tokens.map { $0.token })
                    return formatted
                }
            }
        } catch {
            let offset: Int
            if let pt = tokens.last {
                offset = Int(pt.endCharacter) + 1
            } else {
                offset = Int(lexer.character)
            }
//            print("*** Error found at offset \(offset): \(error)")
            let index = sparql.index(sparql.startIndex, offsetBy: offset)
            let prefix = self.serialize(tokens.map { $0.token })
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//            print("Reformatted prefix: <<<\(prefix)>>>")
            let suffix = sparql[index...]
//            print("Rest of string: <<<\(suffix)>>>")
            let formatted = "\(prefix) \(suffix)"
            return formatted
        }
    }
    
    public func serialize(_ algebra: Algebra) throws -> String {
        return try self.serialize(algebra.sparqlQueryTokens())
    }
    
    public func serialize<S: Sequence>(_ tokens: S) -> String where S.Iterator.Element == SPARQLToken {
        var s = ""
        self.serialize(tokens, to: &s)
        return s
    }

    public func serialize<S: Sequence, Target: TextOutputStream>(_ tokens: S, to output: inout Target) where S.Iterator.Element == SPARQLToken {
        if prettyPrint {
            serializePretty(tokens, to: &output)
        } else {
            serializePlain(tokens, to: &output)
        }
    }
    
    internal func serializePlain<S: Sequence, Target: TextOutputStream>(_ tokens: S, to output: inout Target) where S.Iterator.Element == SPARQLToken {
        var lastWasWhitespace = false
        for (i, token) in tokens.enumerated() {
            if i > 0 {
                if !lastWasWhitespace {
                    print(" ", terminator: "", to: &output)
                }
            }
            let string = "\(token.sparql)"
            print(string, terminator: "", to: &output)
            lastWasWhitespace = string.hasSuffix("\n") || string.hasSuffix(" ")
        }
    }
    
    private struct ParseState {
        // swiftlint:disable:next nesting
        struct NestingCallback {
            let level: [Int]
        }
        
        var indentLevel: Int   = 0
        var inSemicolon: Bool  = false
        var openParens: Int    = 0
        //        {
        //            didSet { checkCallbacks() }
        //        }
        var openBraces: Int    = 0
        //        {
        //            didSet { checkCallbacks() }
        //        }
        var openBrackets: Int  = 0
        //        {
        //            didSet { checkCallbacks() }
        //        }
        var callbackStack: [NestingCallback] = []
        //        mutating func checkCallbacks() {
        //            let currentLevel = [openBraces, openBrackets, openParens]
        //            //        println("current level: \(currentLevel)")
        //            if let top = callbackStack.last {
        //                //            println("-----> callback set for level: \(top.level)")
        //                if top.level == currentLevel {
        //                    //                println("*** MATCHED")
        //                    top.code(self)
        //                    callbackStack.removeLast()
        //                }
        //            }
        //        }
        
        mutating func checkBookmark() -> Bool {
            let currentLevel = [openBraces, openBrackets, openParens]
            if let top = callbackStack.last {
                if top.level == currentLevel {
                    callbackStack.removeLast()
                    return true
                }
            }
            return false
        }
        
        mutating func registerForClose() {
            let currentLevel = [openBraces, openBrackets, openParens]
            let cb = NestingCallback(level: currentLevel)
            callbackStack.append(cb)
        }
    }
    
    struct SerializerState {
        var spaceSeparator = " "
        var indent = "    "
    }
    
    enum SerializerOutput : Equatable {
        case newline(Int)
        case spaceSeparator
        case tokenString(String)
        
        var description: String {
            switch self {
            case .newline:
                return "␤"
            case .spaceSeparator:
                return "␠"
            case .tokenString(let s):
                return "\"\(s)\""
            }
        }
    }
    
    internal func serializePretty<S: Sequence>(_ tokenSequence: S) -> String where S.Iterator.Element == SPARQLToken {
        var s = ""
        self.serializePretty(tokenSequence, to: &s)
        return s
    }
    
    internal func fixBrackettedExpressions(_ outputArray: [(SPARQLToken, SerializerOutput)]) -> [(SPARQLToken, SerializerOutput)] {
        // Look for bracketted FILTER and BIND expressions, and add a newline after their closing rparen.
        // This will ensure that a triple pattern after a BIND will appear on its own line, for example:
        // "BIND(1 AS ?x) ?s ?p ?o" -> "BIND (1 AS ?x)\n?s ?p ?o"
        var outputArray = outputArray
        
        // append some extra whitespace tokens so we can easily do 2-token lookahead
        outputArray.append((.ws, .spaceSeparator))
        outputArray.append((.ws, .spaceSeparator))
        outputArray.append((.ws, .spaceSeparator))
        var processedArray: [(SPARQLToken, SerializerOutput)] = []
        var inCall: Int = 0
        var closingDepth = Set<Int>()
        var indentDepth = [Int:Int]()
        var depth = 0
        for i in 0..<(outputArray.count-2) {
            let (t1, s1) = outputArray[i]
            processedArray.append((t1, s1))
            if case .newline(let i) = s1 {
                indentDepth[depth] = i
            }
            
            var needsNewline = false
            let (_, s2) = outputArray[i+1]
            let (_, s3) = outputArray[i+2]
            switch (s1, s2, s3) {
            case (.tokenString("FILTER"), .spaceSeparator, .tokenString("(")), (.tokenString("BIND"), .spaceSeparator, .tokenString("(")):
                inCall += 1
                closingDepth.insert(depth)
            case (.tokenString("FILTER"), _, _), (.tokenString("BIND"), _, _): // may be a built-in call or an un-bracketted function call
                inCall += 1
                closingDepth.insert(depth)
            case (.tokenString("("), _, _) where inCall > 0:
                depth += 1
            case (.tokenString(")"), .spaceSeparator, .tokenString(".")) where inCall > 0: // no newline if there's a DOT after the RPAREN
                depth -= 1
                if (closingDepth.contains(depth) || depth == 0) {
                    closingDepth.remove(depth)
                    inCall -= 1
                }
            case (.tokenString(")"), .spaceSeparator, .tokenString("ASC")) where inCall > 0,
                (.tokenString(")"), .spaceSeparator, .tokenString("DESC")) where inCall > 0: // no newline if there's a sort direction after the RPAREN
                depth -= 1
                if (closingDepth.contains(depth) || depth == 0) {
                    closingDepth.remove(depth)
                    inCall -= 1
                }
            case (.tokenString(")"), _, _) where inCall > 0:
                depth -= 1
                if (closingDepth.contains(depth) || depth == 0) {
                    closingDepth.remove(depth)
                    needsNewline = true
                    inCall -= 1
                }
            case (.tokenString("()"), _, _) where inCall > 0 && depth == 0:
                needsNewline = true
                inCall -= 1
            default:
                break
            }
            if needsNewline {
                let i = indentDepth[depth] ?? 0
                processedArray.append((t1, .newline(i)))
            }
        }
        return processedArray
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    internal func serializePretty<S: Sequence, Target: TextOutputStream>(_ tokenSequence: S, to output: inout Target) where S.Iterator.Element == SPARQLToken {
        var tokens = Array(tokenSequence)
        tokens.append(.ws)
        var outputArray: [(SPARQLToken, SerializerOutput)] = []
        var pstate = ParseState()
        //        var sstate_stack = [SerializerState()]
        for i in 0..<(tokens.count-1) {
            let t = tokens[i]
            let u = tokens[i+1]
            //        println("handling token: \(t.sparqlStringWithDefinedPrefixes([:]))")
            
            if case .rbrace = t {
                pstate.openBraces -= 1
                pstate.indentLevel -= 1
                pstate.inSemicolon  = false
                if pstate.checkBookmark() {
                    outputArray.append((t, .newline(pstate.indentLevel)))
                }
            }
            
            //                let value = t.value() as! String
            let state = (pstate.openBraces, t, u)
            
            switch state {
            case (_, .keyword("FILTER"), .lparen), (_, .keyword("BIND"), .lparen), (_, .keyword("HAVING"), .lparen):
                pstate.registerForClose()
            default:
                break
            }
            
            switch state {
            case (_, .lbrace, _):
                //                 '{' $            -> '{' NEWLINE_INDENT
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(1+pstate.indentLevel)))
            case (0, _, .lbrace):
                // {openBraces=0}    $ '{'            -> $
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .rbrace, .keyword("UNION")), (_, .rbrace, .keyword("MINUS")):
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .rbrace, _):
                // a right brace should be on a line by itself
                //                 '}' $            -> NEWLINE_INDENT '}' NEWLINE_INDENT
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, .keyword("EXISTS"), .lbrace), (_, .keyword("OPTIONAL"), .lbrace), (_, .keyword("UNION"), .lbrace), (_, .keyword("MINUS"), .lbrace):
                //                 EXISTS '{'        -> EXISTS SPACE_SEP
                //                 OPTIONAL '{'    -> OPTIONAL SPACE_SEP
                //                 UNION '{'        -> UNION SPACE_SEP
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .comment(let c), _):
                if c.count > 0 {
                    var string = "\(t.sparql)"
                    if string.hasSuffix("\n") {
                        string.removeLast()
                    }
                    
                    outputArray.append((t, .tokenString(string)))
                    outputArray.append((t, .newline(pstate.indentLevel)))
                }
            case(_, .bang, _):
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .rparen, .lbrace):
                // this occurs in VALUES blocks: VALUES (?x) { (...) (...) }
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
//            case (_, .rparen, .lparen):
//                // this occurs in VALUES blocks: VALUES (?x) { (...) (...) }
//                // TODO: but we only want the newline in VALUES, not in select expressions: SELECT (SUM(?o) AS ?s) (AVG(?o) AS ?a) ...
//                outputArray.append((t, .tokenString("\(t.sparql)")))
//                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, .keyword("WHERE"), .lbrace):
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, _, .lbrace):
                // {openBraces=_}    $ '{'            -> $ NEWLINE_INDENT
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, _, .keyword("BASE")), (_, _, .keyword("PREFIX")),
                (_, _, .keyword("SELECT")), (_, _, .keyword("ASK")), (_, _, .keyword("CONSTRUCT")), (_, _, .keyword("DESCRIBE")),
                (_, _, .keyword("FROM")),
                (_, _, .keyword("INSERT")), (_, _, .keyword("DELETE")),
                (_, _, .keyword("LOAD")), (_, _, .keyword("CLEAR")),
                (_, _, .keyword("DROP")), (_, _, .keyword("CREATE")),
                (_, _, .keyword("ADD")), (_, _, .keyword("MOVE")),
                (_, _, .keyword("COPY")), (_, _, .keyword("CREATE")),
                (_, _, .keyword("WITH")):
                // newline before these keywords
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, .iri, .keyword("WHERE")), (_, .prefixname, .keyword("WHERE")):
                // newline between an IRI (or prefixed name) and WHERE (as in `SELECT * FROM <a> WHERE { … }`)
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, .keyword("ORDER"), _) where pstate.openParens > 0:
                // no newline before an ORDER BY clause that's within a set of parens (e.g. as part of a window function)
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .keyword("GROUP"), _), (_, .keyword("HAVING"), _), (_, .keyword("ORDER"), _), (_, .keyword("LIMIT"), _), (_, .keyword("OFFSET"), _):
                // newline before, and a space after these keywords
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .dot, _):
                // newline after all DOTs
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel)))
            case (_, .semicolon, .keyword("SEPARATOR")):
                // suppress newline after SEMICOLON used in GROUP_CONCAT; use a space instead
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .semicolon, _):
                // newline after all other SEMICOLONs
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .newline(pstate.indentLevel+1)))
            case (_, .keyword("FILTER"), .lparen), (_, .keyword("BIND"), .lparen):
                // newline before these keywords
                //                 'FILTER' $        -> NEWLINE_INDENT 'FILTER'                { set no SPACE_SEP }
                //                 'BIND' '('        -> NEWLINE_INDENT 'BIND'                { set no SPACE_SEP }
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .keyword("FILTER"), _), (_, .keyword("BIND"), _):
                // newline before these keywords
                //                 'FILTER' $        -> NEWLINE_INDENT 'FILTER'                { set no SPACE_SEP }
                //                 'BIND' '('        -> NEWLINE_INDENT 'BIND'                { set no SPACE_SEP }
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            case (_, .hathat, _):
                // no trailing whitespace after ^^ (it's probably followed by an IRI or PrefixName)
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .keyword("ASC"), _), (_, .keyword("DESC"), _):
                // no trailing whitespace after these keywords (they're probably followed by a LPAREN
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, _, .rparen):
                // no space between any token and a following rparen
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .lparen, _):
                // no space between a lparen and any following token
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .keyword(let kw), .lparen) where SPARQLLexer.validAggregations.contains(kw):
                //                 KEYWORD '('        -> KEYWORD                                { set no SPACE_SEP }
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .keyword(let kw), .lparen) where SPARQLLexer.validFunctionNames.contains(kw):
                //                 KEYWORD '('        -> KEYWORD                                { set no SPACE_SEP }
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .prefixname, .lparen):
                // function call; supress space between function IRI and opening paren
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, _, .hathat), (_, _, .lang):
                // no space in between any token and a ^^ or @lang
                outputArray.append((t, .tokenString("\(t.sparql)")))
                
            case (_, .hat, .iri), (_, .hat, .prefixname):
                // no whitespace between ^ and an IRI (or prefixed name) (property path)
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .rparen, .star) where pstate.openParens == 1,
                (_, .rparen, .plus) where pstate.openParens == 1:
                // no space between a rparen and a star or plus while NOT within another set of parens (property path)
                // this will handle paths like (ex:foo+/ex:bar)*, but not ((ex:foo/ex:bar)*/ex:baz)
                outputArray.append((t, .tokenString("\(t.sparql)")))

            case (_, .iri, .plus), (_, .prefixname, .plus), (_, .iri, .star), (_, .prefixname, .star):
                // no space in between an IRI or PrefixedName token and a plus or a star (property path)
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .or, _), (_, _, .or):
                // no whitespace surrounding an '|' (property path)
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .iri, .slash), (_, .prefixname, .slash), (_, .slash, .iri), (_, .slash, .prefixname),
                (_, .plus, .slash), (_, .star, .slash):
                // no space in between an IRI or PrefixedName token and a slash or pipe (property path)
                // no space in between a slash and an IRI or PrefixedName token (property path)
                outputArray.append((t, .tokenString("\(t.sparql)")))
            case (_, .keyword("VALUES"), _):
                outputArray.append((t, .newline(pstate.indentLevel)))
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            default:
                //                 $ $                -> $ ' '
                outputArray.append((t, .tokenString("\(t.sparql)")))
                outputArray.append((t, .spaceSeparator))
            }
            
            switch t {
            case .dot:
                pstate.inSemicolon  = false
            case .lbrace:
                pstate.indentLevel += 1
                pstate.openBraces += 1
            case .lbracket:
                pstate.openBrackets += 1
            case .rbracket:
                pstate.openBrackets -= 1
            case .lparen:
                pstate.openParens += 1
                pstate.indentLevel += 1
            case .rparen:
                pstate.openParens -= 1
                pstate.indentLevel -= 1
            default:
                break
            }
        }
        
        guard !outputArray.isEmpty else {
            return
        }
        
        outputArray = fixBrackettedExpressions(outputArray)
        
        var tempArray: [SerializerOutput] = []
        FILTER: for i in 0..<(outputArray.count-2) {
            let (_, s1) = outputArray[i]
            let (_, s2) = outputArray[i+1]
            switch (s1, s2) {
            case (.spaceSeparator, .newline), (.newline, .newline):
                // skip whitespace appearing before a newline
                continue FILTER
            case (.newline, .spaceSeparator):
                // change newline-space to newline-newline, and then skip the first newline
                // (resulting in a single newline being handled)
                outputArray[i+1] = outputArray[i]
                continue FILTER
            case (.newline(_), .tokenString("OPTIONAL")) where tempArray.last == .some(.tokenString("}")),
                (.newline(_), .tokenString("UNION")) where tempArray.last == .some(.tokenString("}")):
                // remove newline between a rbrace and OPTIONAL/UNION to allow the syntax "} UNION {" on one line
                tempArray.append(.spaceSeparator)
                continue FILTER
            case (.newline(_), .tokenString("EXISTS")) where tempArray.last == .some(.tokenString("NOT")):
                // remove newline between a NOT and EXISTS
                tempArray.append(.spaceSeparator)
                continue FILTER
            default:
                tempArray.append(s1)
            }
        }
        LOOP: while tempArray.count > 0 {
            if let l = tempArray.last {
                switch l {
                case .tokenString:
                    break LOOP
                default:
                    tempArray.removeLast()
                }
            } else {
                break
            }
        }
        
        // build up the output string
        var pretty = ""
        for s in tempArray {
            switch s {
            case .newline(let indent):
                pretty += "\n"
                if indent > 0 {
                    for _ in 0..<indent {
                        pretty += "    "
                    }
                }
            case .spaceSeparator:
                pretty += " "
            case .tokenString(let string):
                pretty += string
            }
        }
        
        print(pretty, to: &output)
    }
    
}

extension Term {
    public var sparqlTokens: AnySequence<SPARQLToken> {
        switch self.type {
        case .blank:
            return AnySequence([.bnode(self.value)])
        case .iri:
            return AnySequence([.iri(self.value)])
        case .datatype(.string):
            return AnySequence<SPARQLToken>([.string1d(self.value)])
        case .datatype(let d):
            return AnySequence<SPARQLToken>([.string1d(self.value), .hathat, .iri(d.value)])
        case .language(let l):
            return AnySequence<SPARQLToken>([.string1d(self.value), .lang(l)])
        }
    }
}

extension Node {
    public var sparqlTokens: AnySequence<SPARQLToken> {
        switch self {
        case .variable(let name, _):
            return AnySequence([._var(name)])
        case .bound(let term):
            return term.sparqlTokens
        }
    }
}

extension TriplePattern {
    public var sparqlTokens: AnySequence<SPARQLToken> {
        var tokens = [SPARQLToken]()
        tokens.append(contentsOf: self.subject.sparqlTokens)
        
        if self.predicate == .bound(Term.rdf("type")) {
            tokens.append(.keyword("A"))
        } else {
            tokens.append(contentsOf: self.predicate.sparqlTokens)
        }
        tokens.append(contentsOf: self.object.sparqlTokens)
        tokens.append(.dot)
        return AnySequence(tokens)
    }
}

extension QuadPattern {
    public var sparqlTokens: AnySequence<SPARQLToken> {
        var tokens = [SPARQLToken]()
        tokens.append(.keyword("GRAPH"))
        tokens.append(contentsOf: self.graph.sparqlTokens)
        tokens.append(.lbrace)
        tokens.append(contentsOf: self.subject.sparqlTokens)
        if self.predicate == .bound(Term.xsd("type")) {
            tokens.append(.keyword("A"))
        } else {
            tokens.append(contentsOf: self.predicate.sparqlTokens)
        }
        tokens.append(contentsOf: self.object.sparqlTokens)
        tokens.append(.dot)
        tokens.append(.rbrace)
        return AnySequence(tokens)
    }
}

extension PropertyPath {
    private var sequenceTerms: [Term]? {
        switch self {
        case let .link(iri):
            return [iri]
        case let .seq(lhs, rhs):
            if let l = lhs.sequenceTerms, let r = rhs.sequenceTerms {
                return l + r
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    private var alternativeTerms: [Term]? {
        switch self {
        case let .link(iri):
            return [iri]
        case let .alt(lhs, rhs):
            if let l = lhs.alternativeTerms, let r = rhs.alternativeTerms {
                return l + r
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    private var parenthesizedSparqlTokens: AnySequence<SPARQLToken> {
        switch self {
        case .link:
            return sparqlTokens
        default:
            let tokens = Array(sparqlTokens)
            let p = [.lparen] + tokens + [.rparen]
            return AnySequence(p)
        }
    }
    
    public var sparqlTokens: AnySequence<SPARQLToken> {
        var tokens = [SPARQLToken]()
        switch self {
        case .link(let term):
            tokens.append(contentsOf: term.sparqlTokens)
        case .inv(let path):
            tokens.append(.hat)
            tokens.append(contentsOf: path.parenthesizedSparqlTokens)
        case .nps(let terms):
            tokens.append(.bang)
            tokens.append(.lparen)
            for (n, term) in terms.enumerated() {
                if n > 0 {
                    tokens.append(.or)
                }
                tokens.append(contentsOf: term.sparqlTokens)
            }
            tokens.append(.rparen)
        case .alt(let lhs, let rhs):
            if let terms = self.alternativeTerms {
                tokens.append(contentsOf: terms.map { $0.sparqlTokens }.joined(separator: [.or]))
            } else {
                tokens.append(contentsOf: lhs.parenthesizedSparqlTokens)
                tokens.append(.or)
                tokens.append(contentsOf: rhs.parenthesizedSparqlTokens)
            }
        case .seq(let lhs, let rhs):
            if let terms = self.sequenceTerms {
                tokens.append(contentsOf: terms.map { $0.sparqlTokens }.joined(separator: [.slash]))
            } else {
                tokens.append(contentsOf: lhs.parenthesizedSparqlTokens)
                tokens.append(.slash)
                tokens.append(contentsOf: rhs.parenthesizedSparqlTokens)
            }
        case .plus(let path):
            tokens.append(contentsOf: path.parenthesizedSparqlTokens)
            tokens.append(.plus)
        case .star(let path):
            tokens.append(contentsOf: path.parenthesizedSparqlTokens)
            tokens.append(.star)
        case .zeroOrOne(let path):
            tokens.append(contentsOf: path.parenthesizedSparqlTokens)
            tokens.append(.question)
        }
        return AnySequence(tokens)
    }
}

extension Expression {
    public var needsSurroundingParentheses: Bool {
        switch self {
        case .node, .isiri, .isblank, .isliteral, .isnumeric, .exists, .not(.exists), .call, .datatype, .lang, .langmatches(_, _), .sameterm(_, _), .bound:
            return false
        default:
            return true
        }
    }
    
    internal func parenthesizedSparqlTokens() throws -> AnySequence<SPARQLToken> {
        switch self {
        case let e where e.needsSurroundingParentheses:
            let tokens = try Array(sparqlTokens())
            let p = [.lparen] + tokens + [.rparen]
            return AnySequence(p)
        default:
            return try sparqlTokens()
        }
    }

    public func sparqlTokens() throws -> AnySequence<SPARQLToken> {
        var tokens = [SPARQLToken]()
        switch self {
        case .node(let n):
            return n.sparqlTokens
        case .aggregate(let a):
            return try a.sparqlTokens()
        case .window(let w):
            return try w.sparqlTokens()
        case .neg(let e):
            tokens.append(.minus)
            tokens.append(contentsOf: try e.parenthesizedSparqlTokens())
        case .not(.exists(let lhs)):
            tokens.append(.keyword("NOT"))
            tokens.append(.keyword("EXISTS"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        case .not(let e):
            tokens.append(.bang)
            tokens.append(contentsOf: try e.parenthesizedSparqlTokens())
        case .isiri(let e):
            tokens.append(.keyword("ISIRI"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .isblank(let e):
            tokens.append(.keyword("ISBLANK"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .isliteral(let e):
            tokens.append(.keyword("ISLITERAL"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .isnumeric(let e):
            tokens.append(.keyword("ISNUMERIC"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .lang(let e):
            tokens.append(.keyword("LANG"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .sameterm(let lhs, let rhs):
            tokens.append(.keyword("SAMETERM"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try lhs.sparqlTokens())
            tokens.append(.comma)
            tokens.append(contentsOf: try rhs.sparqlTokens())
            tokens.append(.rparen)
        case .langmatches(let e, let p):
            tokens.append(.keyword("LANGMATCHES"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.comma)
            tokens.append(contentsOf: try p.sparqlTokens())
            tokens.append(.rparen)
        case .datatype(let e):
            tokens.append(.keyword("DATATYPE"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .bound(let e):
            tokens.append(.keyword("BOUND"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .boolCast(let e):
            tokens.append(contentsOf: Term.xsd("boolean").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .intCast(let e):
            tokens.append(contentsOf: Term.xsd("integer").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .floatCast(let e):
            tokens.append(contentsOf: Term.xsd("float").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .doubleCast(let e):
            tokens.append(contentsOf: Term.xsd("double").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .decimalCast(let e):
            tokens.append(contentsOf: Term.xsd("decimal").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .dateTimeCast(let e):
            tokens.append(contentsOf: Term.xsd("dateTime").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .dateCast(let e):
            tokens.append(contentsOf: Term.xsd("date").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .stringCast(let e):
            tokens.append(contentsOf: Term.xsd("string").sparqlTokens)
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .eq(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.equals)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .ne(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.notequals)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .lt(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.lt)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .le(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.le)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .gt(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.gt)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .ge(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.ge)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .add(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.plus)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .sub(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.minus)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .div(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.slash)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .mul(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.star)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .and(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.andand)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .or(let lhs, let rhs):
            tokens.append(contentsOf: try lhs.parenthesizedSparqlTokens())
            tokens.append(.oror)
            tokens.append(contentsOf: try rhs.parenthesizedSparqlTokens())
        case .between(let e, let lhs, let rhs):
            let expr : Expression = .and(.ge(e, lhs), .le(e, rhs))
            return try expr.sparqlTokens()
        case .valuein(let e, let values):
            tokens.append(contentsOf: try e.parenthesizedSparqlTokens())
            tokens.append(.keyword("IN"))
            tokens.append(.lparen)
            for (i, v) in values.enumerated() {
                if i > 0 {
                    tokens.append(.comma)
                }
                tokens.append(contentsOf: try v.sparqlTokens())
            }
            tokens.append(.rparen)
        case .call(let f, let values):
            if SPARQLLexer.validFunctionNames.contains(f) {
                tokens.append(.keyword(f))
            } else {
                let term = Term(iri: f)
                tokens.append(contentsOf: term.sparqlTokens)
            }
            tokens.append(.lparen)
            for (i, v) in values.enumerated() {
                if i > 0 {
                    tokens.append(.comma)
                }
                tokens.append(contentsOf: try v.sparqlTokens())
            }
            tokens.append(.rparen)
        case .exists(let lhs):
            tokens.append(.keyword("EXISTS"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        }
        return AnySequence(tokens)
    }
}

extension Aggregation {
    public func sparqlTokens() throws -> AnySequence<SPARQLToken> {
        var tokens = [SPARQLToken]()
        switch self {
        case .countAll(let distinct):
            tokens.append(.keyword("COUNT"))
            tokens.append(.lparen)
            if distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            tokens.append(.star)
            tokens.append(.rparen)
        case .count(let e, let distinct):
            tokens.append(.keyword("COUNT"))
            tokens.append(.lparen)
            if distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .sum(let e, let distinct):
            tokens.append(.keyword("SUM"))
            tokens.append(.lparen)
            if distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .avg(let e, let distinct):
            tokens.append(.keyword("AVG"))
            tokens.append(.lparen)
            if distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .min(let e):
            tokens.append(.keyword("MIN"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .max(let e):
            tokens.append(.keyword("MAX"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .sample(let e):
            tokens.append(.keyword("SAMPLE"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try e.sparqlTokens())
            tokens.append(.rparen)
        case .groupConcat(let e, let sep, let distinct):
            tokens.append(.keyword("GROUP_CONCAT"))
            tokens.append(.lparen)
            if distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            tokens.append(contentsOf: try e.sparqlTokens())
            if sep != " " {
                tokens.append(.semicolon)
                tokens.append(.keyword("SEPARATOR"))
                tokens.append(.equals)
                let t = Term(string: sep)
                tokens.append(contentsOf: t.sparqlTokens)
            }
            tokens.append(.rparen)
        }
        return AnySequence(tokens)
    }
}

extension Algebra {
    var serializableEquivalent: Algebra {
        switch self {
        case .unionIdentity:
            fatalError("cannot serialize the union identity in SPARQL")
        case .joinIdentity:
            return self
        case .quad, .triple, .table, .bgp:
            return self
        case .innerJoin(let lhs, let rhs):
            return .innerJoin(lhs.serializableEquivalent, rhs.serializableEquivalent)
        case .leftOuterJoin(let lhs, let rhs, let expr):
            return .leftOuterJoin(lhs.serializableEquivalent, rhs.serializableEquivalent, expr)
        case .filter(let lhs, let expr):
            return .filter(lhs.serializableEquivalent, expr)
        case .union(let lhs, let rhs):
            return .union(lhs.serializableEquivalent, rhs.serializableEquivalent)
        case .namedGraph(let lhs, let graph):
            return .namedGraph(lhs.serializableEquivalent, graph)
        case .extend(let lhs, let expr, let name):
            return .extend(lhs.serializableEquivalent, expr, name)
        case .minus(let lhs, let rhs):
            return .minus(lhs.serializableEquivalent, rhs.serializableEquivalent)
        case .project(let lhs, let names):
            return .project(lhs.serializableEquivalent, names)
        case .distinct(let lhs):
            switch lhs {
            case .slice, .order, .aggregate, .project:
                return .distinct(lhs.serializableEquivalent)
            default:
                return .distinct(.project(lhs.serializableEquivalent, lhs.inscope))
            }
        case .service(let endpoint, let sparql, let silent):
            return .service(endpoint, sparql, silent)
        case .slice(let lhs, let offset, let limit):
            switch lhs {
            case .order, .aggregate, .project:
                return .slice(lhs.serializableEquivalent, offset, limit)
            default:
                return .slice(.project(lhs.serializableEquivalent, lhs.inscope), offset, limit)
            }
        case .order(let lhs, let cmps):
            switch lhs {
            case .aggregate, .project:
                return .order(lhs.serializableEquivalent, cmps)
            default:
                return .order(.project(lhs.serializableEquivalent, lhs.inscope), cmps)
            }
        case .path:
            return self
        case .aggregate(let lhs, let groups, let aggs):
            switch lhs {
            case .project:
                return .aggregate(lhs.serializableEquivalent, groups, aggs)
            default:
                fatalError("cannot serialize an aggregation whose child is not a projection operator")
            }
        case .window(let lhs, let funcs):
            return .window(lhs.serializableEquivalent, funcs)
        case .subquery:
            return self
        case .reduced:
            return self
        }
    }
    
    public func sparqlQueryTokens() throws -> AnySequence<SPARQLToken> {
        let a = self.serializableEquivalent
        
        switch a {
        case .project, .aggregate, .order(.project, _), .slice(.project, _, _), .slice(.order(.project, _), _, _), .distinct:
            return try a.sparqlTokens(depth: 0)
        default:
            let wrapped: Algebra = .project(a, a.inscope)
            return try wrapped.sparqlTokens(depth: 0)
        }
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    public func sparqlTokens(depth: Int) throws -> AnySequence<SPARQLToken> {
        switch self {
        case .unionIdentity:
            fatalError("cannot serialize the union identity as a SPARQL token sequence")
        case .joinIdentity:
            return AnySequence([.lbrace, .rbrace])
        case .quad(let q):
            return q.sparqlTokens
        case .triple(let t):
            return t.sparqlTokens
        case .bgp(let triples):
            let tokens = triples.map { $0.sparqlTokens }.flatMap { $0 }
            return AnySequence(tokens)
        case .innerJoin(let rhs, let lhs):
            let tokens = try [rhs, lhs].map { try $0.sparqlTokens(depth: depth) }.flatMap { $0 }
            return AnySequence(tokens)
        case .leftOuterJoin(let lhs, let rhs, let expr):
            var tokens = [SPARQLToken]()
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            tokens.append(.keyword("OPTIONAL"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try rhs.sparqlTokens(depth: depth+1))
            if expr != .trueExpression {
                tokens.append(.keyword("FILTER"))
                var addParens : Bool = expr.needsSurroundingParentheses
                if case .node = expr {
                    addParens = true
                }
                
                if addParens {
                    tokens.append(.lparen)
                    tokens.append(contentsOf: try expr.sparqlTokens())
                    tokens.append(.rparen)
                } else {
                    tokens.append(contentsOf: try expr.sparqlTokens())
                }
            }
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .minus(let lhs, let rhs):
            var tokens = [SPARQLToken]()
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            tokens.append(.keyword("MINUS"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try rhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .filter(let lhs, let expr):
            var tokens = [SPARQLToken]()
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth))
            tokens.append(.keyword("FILTER"))
            var addParens : Bool = expr.needsSurroundingParentheses
            if case .node = expr {
                addParens = true
            }
            
            if addParens {
                tokens.append(.lparen)
                tokens.append(contentsOf: try expr.sparqlTokens())
                tokens.append(.rparen)
            } else {
                tokens.append(contentsOf: try expr.sparqlTokens())
            }
            return AnySequence(tokens)
        case .union(let lhs, let rhs):
            var tokens = [SPARQLToken]()
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            tokens.append(.keyword("UNION"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try rhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .namedGraph(let lhs, let graph):
            var tokens = [SPARQLToken]()
            tokens.append(.keyword("GRAPH"))
            tokens.append(contentsOf: graph.sparqlTokens)
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .service(let endpoint, let lhs, let silent):
            var tokens = [SPARQLToken]()
            tokens.append(.keyword("SERVICE"))
            if silent {
                tokens.append(.keyword("SILENT"))
            }
            tokens.append(.iri(endpoint.absoluteString))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .extend(let lhs, let expr, let name):
            var tokens = [SPARQLToken]()
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth))
            tokens.append(.keyword("BIND"))
            tokens.append(.lparen)
            tokens.append(contentsOf: try expr.sparqlTokens())
            tokens.append(.keyword("AS"))
            tokens.append(._var(name))
            tokens.append(.rparen)
            return AnySequence(tokens)
        case .table(let nodes, let rows):
            var tokens = [SPARQLToken]()
            tokens.append(.keyword("VALUES"))
            tokens.append(.lparen)
            tokens.append(contentsOf: nodes.map { $0.sparqlTokens }.flatMap { $0 })
            tokens.append(.rparen)
            tokens.append(.lbrace)
            for row in rows {
                tokens.append(.lparen)
                for n in row {
                    if let term = n {
                        tokens.append(contentsOf: term.sparqlTokens)
                    } else {
                        tokens.append(.keyword("UNDEF"))
                    }
                }
                tokens.append(.rparen)
            }
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .project(let lhs, _), .distinct(let lhs), .reduced(let lhs), .slice(let lhs, _, _), .order(let lhs, _):
            var tokens = [SPARQLToken]()
            // projection, ordering, distinct, and slice serialization happens in Query.sparqlTokens, so this just serializes the child algebra
            tokens.append(contentsOf: try lhs.sparqlTokens(depth: depth+1))
            return AnySequence(tokens)
        case .path(let lhs, let path, let rhs):
            var tokens = [SPARQLToken]()
            tokens.append(contentsOf: lhs.sparqlTokens)
            tokens.append(contentsOf: path.sparqlTokens)
            tokens.append(contentsOf: rhs.sparqlTokens)
            tokens.append(.dot)
            return AnySequence(tokens)
        case .subquery(let q):
            var tokens = [SPARQLToken]()
            tokens.append(.lbrace)
            tokens.append(contentsOf: try q.sparqlTokens())
            tokens.append(.rbrace)
            return AnySequence(tokens)
        case .aggregate(let lhs, _, _):
            // aggregation serialization happens in Query.sparqlTokens, so this just serializes the child algebra
            return try lhs.sparqlTokens(depth: depth)
        case .window(let lhs, _):
            // window serialization happens in Query.sparqlTokens, so this just serializes the child algebra
            return try lhs.sparqlTokens(depth: depth)
        }
    }
}

extension Query {
    public func sparqlTokens() throws -> AnySequence<SPARQLToken> {
        
        var algebra = self.algebra
        var projectedExpressions = [String:[SPARQLToken]]()
        var groupTokens = [SPARQLToken]()
        let aggMods = algebra.aggregationModifiers()
        let aggExtensions = algebra.variableExtensions
        if let a = algebra.aggregation, case let .aggregate(_, groups, aggs) = a {
            for aggMap in aggs {
                let v = aggMap.variableName
                projectedExpressions[v] = try Array(aggMap.aggregation.sparqlTokens())
            }
            
            if groups.count > 0 {
                groupTokens.append(.keyword("GROUP"))
                groupTokens.append(.keyword("BY"))
                for (i, g) in groups.enumerated() {
                    if i > 0 {
                        groupTokens.append(.comma)
                    }
                    
                    
                    var addParens : Bool = g.needsSurroundingParentheses
                    if case .node(.bound) = g {
                        addParens = true
                    }
                    
                    if addParens {
                        groupTokens.append(.lparen)
                        groupTokens.append(contentsOf: try g.sparqlTokens())
                        groupTokens.append(.rparen)
                    } else {
                        groupTokens.append(contentsOf: try g.sparqlTokens())
                    }
                    
                    //                    try groupTokens.append(contentsOf: g.sparqlTokens())
                }
            }
            
            algebra = algebra.removeAggregation()
        }
        
        
        if let w = algebra.window, case let .window(_, funcs) = w {
            for f in funcs {
                let v = f.variableName
                projectedExpressions[v] = try Array(f.windowApplication.sparqlTokens())
            }
            
            algebra = algebra.removeWindow()
        }
        
        var aggExtensionTokens = [String : [SPARQLToken]]()
        for (name,e) in aggExtensions {
            let tokens = try Array(e.sparqlTokens())
            let mapped = tokens.map { (t) -> [SPARQLToken] in
                switch t {
                case ._var(let n):
                    if let replacement = projectedExpressions[n] {
                        return replacement
                    }
                default:
                    break
                }
                return [t]
                }.joined()
            let flat = Array(mapped)
            aggExtensionTokens[name] = flat
        }
        
        var tokens = [SPARQLToken]()
        switch self.form {
        case .select(.star):
            tokens.append(.keyword("SELECT"))
            if algebra.distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            // TODO: how to handle REDUCED queries?
            tokens.append(.star)
            tokens.append(.keyword("WHERE"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try algebra.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        case .select(.variables(let vars)):
            tokens.append(.keyword("SELECT"))
            if algebra.distinct {
                tokens.append(.keyword("DISTINCT"))
            }
            // TODO: how to handle REDUCED queries?
            for v in vars {
                if let replacement = aggExtensionTokens[v] {
                    tokens.append(.lparen)
                    tokens.append(contentsOf: replacement)
                    tokens.append(contentsOf: [.keyword("AS"), ._var(v), .rparen])
                    algebra = try algebra.replace({ (a) -> Algebra? in
                        switch a {
                        case .extend(let child, _, v):
                            return child
                        default:
                            return nil
                        }
                    })
                } else if let replacement = projectedExpressions[v] {
                    projectedExpressions.removeValue(forKey: v)
                    tokens.append(.lparen)
                    tokens.append(contentsOf: replacement)
                    tokens.append(contentsOf: [.keyword("AS"), ._var(v), .rparen])
                    algebra = try algebra.replace({ (a) -> Algebra? in
                        switch a {
                        case .extend(let child, _, v):
                            return child
                        default:
                            return nil
                        }
                    })
                } else {
                    let v : Node = .variable(v, binding: true)
                    tokens.append(contentsOf: v.sparqlTokens)
                }
            }
            tokens.append(.keyword("WHERE"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try algebra.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
            
            for t in groupTokens {
                switch t {
                case ._var(let v):
                    if let replacement = projectedExpressions[v] {
                        tokens.append(contentsOf: replacement)
                    } else {
                        tokens.append(t)
                    }
                default:
                    tokens.append(t)
                }
            }

            if aggMods.having.count > 0 {
                tokens.append(.keyword("HAVING"))
                for expr in aggMods.having {
                    for t in try expr.parenthesizedSparqlTokens() {
                        switch t {
                        case ._var(let v):
                            if let replacement = projectedExpressions[v] {
                                tokens.append(contentsOf: replacement)
                            } else {
                                tokens.append(t)
                            }
                        default:
                            tokens.append(t)
                        }
                    }
                }
            }
        case .ask:
            tokens.append(.keyword("ASK"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try algebra.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        case .describe(let nodes):
            tokens.append(.keyword("DESCRIBE"))
            for n in nodes {
                tokens.append(contentsOf: n.sparqlTokens)
            }
            tokens.append(.keyword("WHERE"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try algebra.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        case .construct(let patterns):
            tokens.append(.keyword("CONSTRUCT"))
            tokens.append(.lbrace)
            for p in patterns {
                tokens.append(contentsOf: p.sparqlTokens)
            }
            tokens.append(.rbrace)
            tokens.append(.keyword("WHERE"))
            tokens.append(.lbrace)
            tokens.append(contentsOf: try algebra.sparqlTokens(depth: 0))
            tokens.append(.rbrace)
        }
        
        switch self.form {
        case .select:
            if let cmps = self.algebra.sortComparators {
                tokens.append(.keyword("ORDER"))
                tokens.append(.keyword("BY"))
                for cmp in cmps {
                    tokens.append(contentsOf: try cmp.sparqlTokens())
                }
            }
        default:
            break
        }
        
        switch self.form {
        case .select, .construct:
            if let offset = self.algebra.offset {
                tokens.append(.keyword("OFFSET"))
                tokens.append(.integer("\(offset)"))
            }
            if let limit = self.algebra.limit {
                tokens.append(.keyword("LIMIT"))
                tokens.append(.integer("\(limit)"))
            }
        default:
            break
        }
        return AnySequence(tokens)
    }
}

internal extension Algebra {
    struct AggregationModifiers {
        var having: [Expression]
    }
    
    func aggregationModifiers() -> AggregationModifiers {
        if self.isAggregation {
            switch self {
            case .aggregate:
                return AggregationModifiers(having: [])
            case let .filter(child, expr):
                var mods = child.aggregationModifiers()
                mods.having.append(expr)
                return mods
            case .project(let child, _), .slice(let child, _, _), .distinct(let child), .order(let child, _):
                return child.aggregationModifiers()
            default:
                break
            }
        }
        return AggregationModifiers(having: [])
    }
    
    func removeAggregation() -> Algebra {
        if self.isAggregation {
            switch self {
            case let .aggregate(child, _, _), let .filter(child, _), let .window(child, _):
                return child.removeAggregation()
            case let .extend(child, expr, name):
                return .extend(child.removeAggregation(), expr, name)
            case let .project(child, vars):
                return .project(child.removeAggregation(), vars)
            case let .slice(child, offset, limit):
                return .slice(child.removeAggregation(), offset, limit)
            case .distinct(let child):
                return .distinct(child.removeAggregation())
            case .order(let child, let cmps):
                return .order(child.removeAggregation(), cmps)
            default:
                fatalError("Unexpected algebra claimed to have an aggregation operator: \(self)")
            }
        }
        return self
    }

    func removeWindow() -> Algebra {
        if self.isWindow {
            switch self {
            case let .aggregate(child, _, _), let .filter(child, _), let .window(child, _):
                return child.removeWindow()
            case let .extend(child, expr, name):
                return .extend(child.removeWindow(), expr, name)
            case let .project(child, vars):
                return .project(child.removeWindow(), vars)
            case let .slice(child, offset, limit):
                return .slice(child.removeWindow(), offset, limit)
            case .distinct(let child):
                return .distinct(child.removeWindow())
            case .order(let child, let cmps):
                return .order(child.removeWindow(), cmps)
            default:
                fatalError("Unexpected algebra claimed to have an window operator: \(self)")
            }
        }
        return self
    }
}

public extension Algebra {
    var sortComparators: [SortComparator]? {
        switch self {
        case .unionIdentity, .joinIdentity:
            return nil
        case .table(_, _), .quad, .triple, .bgp, .innerJoin(_, _), .leftOuterJoin(_, _, _),
             .union(_, _), .minus(_, _), .service(_, _, _), .path(_, _, _),
             .aggregate(_, _, _), .window(_, _), .subquery:
            return nil
        case .filter(let child, _), .namedGraph(let child, _), .extend(let child, _, _), .project(let child, _), .slice(let child, _, _), .distinct(let child), .reduced(let child):
            return child.sortComparators
        case .order(_, let cmps):
            return cmps
        }
    }
    
    var distinct: Bool {
        switch self {
        case .distinct:
            return true
        case .unionIdentity, .joinIdentity:
            return false
        case .table(_, _), .quad, .triple, .bgp, .innerJoin(_, _), .leftOuterJoin(_, _, _),
             .filter(_, _), .union(_, _), .minus(_, _), .service(_, _, _), .path(_, _, _), .namedGraph(_, _),
             .aggregate(_, _, _), .window(_, _), .subquery, .project(_, _):
            return false
        case .extend(let child, _, _), .order(let child, _), .slice(let child, _, _), .reduced(let child):
            return child.distinct
        }
    }
    
    var limit: Int? {
        switch self {
        case .unionIdentity, .joinIdentity:
            return nil
        case .table(_, _), .quad, .triple, .bgp, .innerJoin(_, _), .leftOuterJoin(_, _, _),
             .filter(_, _), .union(_, _), .minus(_, _), .distinct, .reduced, .service(_, _, _), .path(_, _, _),
             .aggregate(_, _, _), .window(_, _), .subquery:
            return nil
        case .namedGraph(let child, _), .extend(let child, _, _), .project(let child, _), .order(let child, _):
            return child.limit
        case .slice(_, _, let l):
            return l
        }
    }
    
    var offset: Int? {
        switch self {
        case .unionIdentity, .joinIdentity:
            return nil
        case .table(_, _), .quad, .triple, .bgp, .innerJoin(_, _), .leftOuterJoin(_, _, _),
             .filter(_, _), .union(_, _), .minus(_, _), .distinct, .reduced, .service(_, _, _), .path(_, _, _),
             .aggregate(_, _, _), .window(_, _), .subquery:
            return nil
        case .namedGraph(let child, _), .extend(let child, _, _), .project(let child, _), .order(let child, _):
            return child.offset
        case .slice(_, let o, _):
            return o
        }
    }
}
