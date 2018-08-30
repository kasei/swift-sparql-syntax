//
//  SPARQLLexer.swift
//  SPARQLParser
//
//  Created by Gregory Todd Williams on 4/23/18.
//

import Foundation

public enum SPARQLToken {
    case ws
    case comment(String)
    case _nil
    case anon
    case double(String)
    case decimal(String)
    case integer(String)
    case hathat
    case lang(String)
    case lparen
    case rparen
    case lbrace
    case rbrace
    case lbracket
    case rbracket
    case equals
    case notequals
    case bang
    case le
    case ge
    case lt
    case gt
    case andand
    case oror
    case semicolon
    case dot
    case comma
    case plus
    case minus
    case star
    case slash
    case _var(String)
    case string3d(String)
    case string3s(String)
    case string1d(String)
    case string1s(String)
    case bnode(String)
    case hat
    case question
    case or
    case prefixname(String, String)
    case boolean(String)
    case keyword(String)
    case iri(String)
    
    public var isVerb: Bool {
        if isTermOrVar {
            return true
        } else {
            switch self {
            case .lparen, .hat, .bang:
                return true
            default:
                return false
            }
        }
    }
    
    public var isTerm: Bool {
        switch self {
        case .keyword("A"):
            return true
        case ._nil, .minus, .plus:
            return true
        case .integer(_), .decimal(_), .double(_), .anon, .boolean(_), .bnode(_), .iri(_), .prefixname(_, _), .string1d(_), .string1s(_), .string3d(_), .string3s(_):
            return true
        default:
            return false
        }
    }
    
    public var isTermOrVar: Bool {
        if isTerm {
            return true
        }
        
        switch self {
        case ._var(_):
            return true
        default:
            return false
        }
    }
    
    public var isNumber: Bool {
        switch self {
        case .integer(_), .decimal(_), .double(_):
            return true
        default:
            return false
        }
    }
    
    public var isString: Bool {
        switch self {
        case .string1d(_), .string1s(_), .string3d(_), .string3s(_):
            return true
        default:
            return false
        }
    }
    
    public var isRelationalOperator: Bool {
        switch self {
        case .lt, .le, .gt, .ge, .equals, .notequals, .andand, .oror:
            return true
        default:
            return false
        }
    }
}

extension SPARQLToken: Equatable {
    public static func == (lhs: SPARQLToken, rhs: SPARQLToken) -> Bool {
        switch (lhs, rhs) {
        case (.comment(let a), .comment(let b)) where a == b:
            return true
        case (.double(let a), .double(let b)) where a == b:
            return true
        case (.decimal(let a), .decimal(let b)) where a == b:
            return true
        case (.integer(let a), .integer(let b)) where a == b:
            return true
        case (.lang(let a), .lang(let b)) where a == b:
            return true
        case (._var(let a), ._var(let b)) where a == b:
            return true
        case (.string3d(let a), .string3d(let b)) where a == b:
            return true
        case (.string3s(let a), .string3s(let b)) where a == b:
            return true
        case (.string1d(let a), .string1d(let b)) where a == b:
            return true
        case (.string1s(let a), .string1s(let b)) where a == b:
            return true
        case (.bnode(let a), .bnode(let b)) where a == b:
            return true
        case (.prefixname(let a, let b), .prefixname(let c, let d)) where a == c && b == d:
            return true
        case (.boolean(let a), .boolean(let b)) where a == b:
            return true
        case (.keyword(let a), .keyword(let b)) where a == b:
            return true
        case (.iri(let a), .iri(let b)) where a == b:
            return true
        case (.ws, .ws), (._nil, ._nil), (.anon, .anon), (.hathat, .hathat), (.lparen, .lparen), (.rparen, .rparen), (.lbrace, .lbrace), (.rbrace, .rbrace), (.lbracket, .lbracket), (.rbracket, .rbracket), (.equals, .equals), (.notequals, .notequals), (.bang, .bang), (.le, .le), (.ge, .ge), (.lt, .lt), (.gt, .gt), (.andand, .andand), (.oror, .oror), (.semicolon, .semicolon), (.dot, .dot), (.comma, .comma), (.plus, .plus), (.minus, .minus), (.star, .star), (.slash, .slash), (.hat, .hat), (.question, .question), (.or, .or):
            return true
        default:
            return false
        }
    }
}

extension SPARQLToken {
    public var sparql: String {
        switch self {
        case .ws:
            return " "
        case .comment(let value):
            return "# \(value)\n"
        case ._nil:
            return "()"
        case .anon:
            return "[]"
        case .double(let value), .decimal(let value), .integer(let value):
            return value
        case .hathat:
            return "^^"
        case .lang(let value):
            return "@\(value)"
        case .lparen:
            return "("
        case .rparen:
            return ")"
        case .lbrace:
            return "{"
        case .rbrace:
            return "}"
        case .lbracket:
            return "["
        case .rbracket:
            return "]"
        case .equals:
            return "="
        case .notequals:
            return "!="
        case .bang:
            return "!"
        case .le:
            return "<="
        case .ge:
            return ">="
        case .lt:
            return "<"
        case .gt:
            return ">"
        case .andand:
            return "&&"
        case .oror:
            return "||"
        case .semicolon:
            return ";"
        case .dot:
            return "."
        case .comma:
            return ","
        case .plus:
            return "+"
        case .minus:
            return "-"
        case .star:
            return "*"
        case .slash:
            return "/"
        case .hat:
            return "^"
        case ._var(let value):
            return "?\(value)"
        case .question:
            return "?"
        case .or:
            return "|"
        case .bnode(let value):
            return "_:\(value)"
        case .string3d(let value):
            return "\"\"\"\(value.escape(for: .literal3d))\"\"\""
        case .string3s(let value):
            return "'''\(value.escape(for: .literal3s))'''"
        case .string1d(let value):
            return "\"\(value.escape(for: .literal1d))\""
        case .string1s(let value):
            return "'\(value.escape(for: .literal1s))'"
        case .prefixname(let ns, let local):
            return "\(ns):\(local.escape(for: .prefixedLocalName))"
        case .boolean(let value):
            return value
        case .keyword(let value):
            if value == "A" {
                return "a"
            }
            return value
        case .iri(let value):
            return "<\(value.escape(for: .iri))>"
        }
    }
}

public struct PositionedToken {
    public var token: SPARQLToken
    public var startColumn: Int
    public var startLine: Int
    public var startCharacter: UInt
    public var endLine: Int
    public var endColumn: Int
    public var endCharacter: UInt
}

// swiftlint:disable:next type_body_length
public class SPARQLLexer: IteratorProtocol {
    var includeComments: Bool
    var source: InputStream
    var lookaheadBuffer: [UInt8]
    var string: String
    var stringPos: UInt
    var line: Int
    var column: Int
    var character: UInt
    var buffer: String
    var startColumn: Int
    var startLine: Int
    var startCharacter: UInt
    var comments: Bool
    var lookahead: PositionedToken?
    
    private func lexError(_ message: String) -> SPARQLSyntaxError {
        try? fillBuffer()
        let rest = buffer
        return SPARQLSyntaxError.lexicalError("\(message) at \(line):\(column) near '\(rest)...'")
    }
    
    private static let rPNameLn    = "((((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[:0-9]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2}))(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})|[:.])*((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[:]|((?:\\\\([-~.!&'()*+,;=/?#@%_\\$]))|%[0-9A-Fa-f]{2})))?))"
    private static let rPNameNS    = "(((([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}])(((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])|[.])*(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|-|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}]))?))?:)"
    private static let rDouble     = "(([0-9]+[.][0-9]*[eE][+-]?[0-9]+)|([.][0-9]+[eE][+-]?[0-9]+)|([0-9]+[eE][+-]?[0-9]+))"
    private static let rDecimal    = "[0-9]*[.][0-9]+"
    private static let rInteger    = "[0-9]+"
    
    private static let _variableNameRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "((([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9])(([_]|([A-Z]|[a-z]|[\\x{00C0}-\\x{00D6}]|[\\x{00D8}-\\x{00F6}]|[\\x{00F8}-\\x{02FF}]|[\\x{0370}-\\x{037D}]|[\\x{037F}-\\x{1FFF}]|[\\x{200C}-\\x{200D}]|[\\x{2070}-\\x{218F}]|[\\x{2C00}-\\x{2FEF}]|[\\x{3001}-\\x{D7FF}]|[\\x{F900}-\\x{FDCF}]|[\\x{FDF0}-\\x{FFFD}]|[\\x{10000}-\\x{EFFFF}]))|[0-9]|\\x{00B7}|[\\x{0300}-\\x{036F}]|[\\x{203F}-\\x{2040}])*)", options: .anchorsMatchLines) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _bnodeNameRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "^([0-9A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])(([A-Za-z_\\x{00C0}-\\x{00D6}\\x{00D8}-\\x{00F6}\\x{00F8}-\\x{02FF}\\x{0370}-\\x{037D}\\x{037F}-\\x{1FFF}\\x{200C}-\\x{200D}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}])|([-0-9\\x{00B7}\\x{0300}-\\x{036F}\\x{203F}-\\x{2040}]))*", options: .anchorsMatchLines) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _keywordRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "(ABS|ADD|ALL|ASC|ASK|AS|AVG|BASE|BIND|BNODE|BOUND|BY|CEIL|CLEAR|COALESCE|CONCAT|CONSTRUCT|CONTAINS|COPY|COUNT|CREATE|DATATYPE|DAY|DEFAULT|DELETE|DELETE WHERE|DESCRIBE|DESC|DISTINCT|DISTINCT|DROP|ENCODE_FOR_URI|EXISTS|FILTER|FLOOR|FROM|GRAPH|GROUP_CONCAT|GROUP|HAVING|HOURS|IF|INSERT|INSERT|DATA|INTO|IN|IRI|ISBLANK|ISIRI|ISLITERAL|ISNUMERIC|ISURI|LANGMATCHES|LANG|LCASE|LIMIT|LOAD|MAX|MD5|MINUS|MINUTES|MIN|MONTH|MOVE|NAMED|NOT|NOW|OFFSET|OPTIONAL|ORDER|PREFIX|RAND|REDUCED|REGEX|REPLACE|ROUND|SAMETERM|SAMPLE|SECONDS|SELECT|SEPARATOR|SERVICE|SHA1|SHA256|SHA384|SHA512|SILENT|STRAFTER|STRBEFORE|STRDT|STRENDS|STRLANG|STRLEN|STRSTARTS|STRUUID|STR|SUBSTR|SUM|TIMEZONE|TO|TZ|UCASE|UNDEF|UNION|URI|USING|UUID|VALUES|WHERE|WITH|YEAR)\\b", options: [.anchorsMatchLines, .caseInsensitive]) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    internal static let validFunctionNames: Set<String> = {
        let funcs = Set(["STR", "LANG", "LANGMATCHES", "DATATYPE", "BOUND", "IRI", "URI", "BNODE", "RAND", "ABS", "CEIL", "FLOOR", "ROUND", "CONCAT", "STRLEN", "UCASE", "LCASE", "ENCODE_FOR_URI", "CONTAINS", "STRSTARTS", "STRENDS", "STRBEFORE", "STRAFTER", "YEAR", "MONTH", "DAY", "HOURS", "MINUTES", "SECONDS", "TIMEZONE", "TZ", "NOW", "UUID", "STRUUID", "MD5", "SHA1", "SHA256", "SHA384", "SHA512", "COALESCE", "IF", "STRLANG", "STRDT", "SAMETERM", "SUBSTR", "REPLACE", "ISIRI", "ISURI", "ISBLANK", "ISLITERAL", "ISNUMERIC", "REGEX"])
        return funcs
    }()
    
    internal static let validAggregations: Set<String> = {
        let aggs = Set(["COUNT", "SUM", "MIN", "MAX", "AVG", "SAMPLE", "GROUP_CONCAT"])
        return aggs
    }()
    
    private static let _aRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "a\\b", options: .anchorsMatchLines) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _booleanRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "(true|false)\\b", options: [.anchorsMatchLines, .caseInsensitive]) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _multiLineAnonRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "(\\[|\\()[\\t\\r\\n ]*$", options: .anchorsMatchLines) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _pNameLNre: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: rPNameLn, options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _pNameNSre: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: rPNameNS, options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _escapedCharRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "\\\\(.)", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _alphanumRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "[0-9A-Fa-f]+", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _iriRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "<([^<>\"{}|^`\\x{00}-\\x{20}])*>", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _unescapedIRIRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "[^>\\\\]+", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _nilRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "[(][ \r\n\t]*[)]", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _doubleRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: rDouble, options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _decimalRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: rDecimal, options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _integerRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: rInteger, options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _anonRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "\\[[ \u{0a}\u{0d}\u{09}]*\\]", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _prefixOrBaseRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "(prefix|base)\\b", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    private static let _langRegex: NSRegularExpression = {
        guard let r = try? NSRegularExpression(pattern: "[a-zA-Z]+(-[a-zA-Z0-9]+)*\\b", options: []) else { fatalError("Failed to compile built-in regular expression") }
        return r
    }()
    
    // PN_CHARS_BASE
    private static let pnCharsBase: CharacterSet = {
        var pn = CharacterSet()
        pn.insert(charactersIn: "a"..."z")
        pn.insert(charactersIn: "A"..."Z")
        
        let ranges: [(Int, Int)] = [
            (0xC0, 0xD6),
            (0xD8, 0xF6),
            (0xF8, 0xFF),
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
    
    private static let pnCharsU: CharacterSet = {
        var pn = pnCharsBase
        pn.insert("_")
        return pn
    }()
    
    private static let pnChars: CharacterSet = {
        var pn = pnCharsU
        pn.insert("-")
        pn.insert(charactersIn: "0"..."9")
        pn.insert(UnicodeScalar(0x00B7))
        let ranges: [(Int, Int)] = [
            (0x0300, 0x036F),
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
    
    
    public init(source: InputStream, includeComments: Bool = false) {
        self.source = source
        self.includeComments = includeComments
        self.lookaheadBuffer = []
        self.string = ""
        self.stringPos = 0
        self.line = 1
        self.column = 1
        self.character = 0
        self.buffer = ""
        self.startColumn = -1
        self.startLine = -1
        self.startCharacter = 0
        self.comments = true
        self.lookahead = nil
    }
    
    public func nextPositionedToken() -> PositionedToken? {
        do {
            return try getToken()
        } catch {
            return nil
        }
    }
    
    public var hasRemainingContent: Bool {
        do {
            guard let _ = try peekChar() else { return false }
            // print("has remaining content: <\(c)>")
            return true
        } catch {
            return false
        }
        
    }
    public func next() -> SPARQLToken? {
        do {
            if let pt : PositionedToken = try getToken() {
                return pt.token
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func readUnicodeEscape(length: Int) throws -> [UInt8] {
        var charbuffer = [UInt8](repeating: 0, count: length)
        let read = source.read(&charbuffer, maxLength: length)
        guard read == length else { throw lexError("Failed to read unicode escape") }
        guard let hex = String(bytes: charbuffer, encoding: .utf8) else { throw lexError("Failed to read unicode escape") }
        guard let codepoint = Int(hex, radix: 16), let us = UnicodeScalar(codepoint) else {
            throw lexError("Invalid unicode codepoint: \(hex)")
        }
        let s = String(us)
        let u = Array(s.utf8)
        return u
    }
    
    func fillBuffer() throws {
        guard source.hasBytesAvailable else { return }
        guard buffer.count == 0 else { return }
        var bytes = [UInt8]()
        var charbuffer: [UInt8] = [0]
        LOOP: while true {
            let read = source.read(&charbuffer, maxLength: 1)
            guard read != -1 else { print("\(source.streamError.debugDescription)"); break }
            guard read > 0 else { break }
            
            if charbuffer[0] == 0x5c {
                // backslash; check for \u or \U escapes
                let read = source.read(&charbuffer, maxLength: 1)
                guard read != -1 else { print("\(source.streamError.debugDescription)"); break }
                guard read > 0 else { break }
                
                switch charbuffer[0] {
                case 0x75: // \u
                    try bytes.append(contentsOf: readUnicodeEscape(length: 4))
                case 0x55: // \U
                    try bytes.append(contentsOf: readUnicodeEscape(length: 8))
                default:
                    bytes.append(0x5c)
                    bytes.append(charbuffer[0])
                }
            } else {
                bytes.append(charbuffer[0])
            }
            
            let wsInts = Set<UInt8>([0x09, 0x0A, 0x0D, 0x20])
            if charbuffer[0] == 0x0a || charbuffer[0] == 0x0d {
                var index = bytes.endIndex
                while true {
                    index = bytes.index(before: index)
                    if wsInts.contains(bytes[index]) {
                        if index == bytes.startIndex {
                            break LOOP
                        } else {
                            continue
                        }
                    } else if bytes[index] == 0x5b || bytes[index] == 0x28 { // [ and (
                        continue LOOP
                    } else {
                        break LOOP
                    }
                }
//                let ws = CharacterSet.whitespacesAndNewlines
//                if let s = String(bytes: bytes, encoding: .utf8) { // TODO: optimize performance
//                    let trimmed = s.trimmingCharacters(in: ws) // TODO: optimize performance
//                    if trimmed.hasSuffix("[") || trimmed.hasSuffix("(") {
//                        continue
//                    }
//                }
                break
            }
        }
        
        guard let s = String(bytes: bytes, encoding: .utf8) else { return }
        buffer = s
    }
    
    func peekToken() throws -> PositionedToken? {
        if let t = lookahead {
            return t
        } else {
            lookahead = try _getToken()
            return lookahead
        }
    }
    
    func getToken() throws -> PositionedToken? {
        if let t = lookahead {
            lookahead = nil
            return t
        } else {
            return try _getToken()
        }
    }
    
    private func packageToken(_ token: SPARQLToken?) -> PositionedToken? {
        guard let token = token else { return nil }
        if self.character == self.startCharacter {
            print("Zero-length token \(startCharacter), \(character): \(token)")
            fatalError()
        }
        return PositionedToken(
            token: token,
            startColumn: startColumn,
            startLine: startLine,
            startCharacter: startCharacter,
            endLine: line,
            endColumn: column,
            endCharacter: character
        )
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    func _getToken() throws -> PositionedToken? {
        while true {
//            try fillBuffer()
            guard var c = try peekChar() else { return nil }
            
            self.startColumn = column
            self.startLine = line
            self.startCharacter = character
            
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                while c == " " || c == "\t" || c == "\n" || c == "\r" {
                    getChar()
                    if let cc = try peekChar() {
                        c = cc
                    } else {
                        return nil
                    }
                }
                continue
            } else if c == "#" {
                var chars = [Character]()
                while c != "\n" && c != "\r" {
                    if let cc = try peekChar() {
                        getChar()
                        c = cc
                        chars.append(cc)
                    } else {
                        if includeComments {
                            let c = String(chars).trimmingCharacters(in: CharacterSet(charactersIn: "#\n\r"))
                            return packageToken(.comment(c))
                        } else {
                            return nil
                        }
                    }
                }
                if includeComments {
                    let c = String(chars).trimmingCharacters(in: CharacterSet(charactersIn: "#\n\r"))
                    return packageToken(.comment(c))
                } else {
                    continue
                }
            }
            
            if buffer.hasPrefix("(") {
                let bufferLength = NSMakeRange(0, buffer.count)
                let nil_range = SPARQLLexer._nilRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
                if nil_range.location == 0 {
                    try read(length: nil_range.length)
                    return packageToken(._nil)
                }
            }
            
            if buffer.hasPrefix("[") {
                let bufferLength = NSMakeRange(0, buffer.count)
                let anon_range = SPARQLLexer._anonRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
                if anon_range.location == 0 {
                    try read(length: anon_range.length)
                    return packageToken(.anon)
                }
            }
            
            switch c {
            case ",":
                getChar()
                return packageToken(.comma)
            case ".":
                getChar()
                return packageToken(.dot)
            case "=":
                getChar()
                return packageToken(.equals)
            case "{":
                getChar()
                return packageToken(.lbrace)
            case "[":
                getChar()
                return packageToken(.lbracket)
            case "(":
                getChar()
                return packageToken(.lparen)
            case "-":
                getChar()
                return packageToken(.minus)
            case "+":
                getChar()
                return packageToken(.plus)
            case "}":
                getChar()
                return packageToken(.rbrace)
            case "]":
                getChar()
                return packageToken(.rbracket)
            case ")":
                getChar()
                return packageToken(.rparen)
            case ";":
                getChar()
                return packageToken(.semicolon)
            case "/":
                getChar()
                return packageToken(.slash)
            case "*":
                getChar()
                return packageToken(.star)
            default:
                break
            }
            
            let us = UnicodeScalar("\(c)")!
            if SPARQLLexer.pnCharsBase.contains(us) {
                if let t = try getPName() {
                    return packageToken(t)
                }
            }
            
            switch c {
            case "@":
                return try packageToken(getLanguage())
            case "<":
                return try packageToken(getIRIRefOrRelational())
            case "?", "$":
                return try packageToken(getVariableOrQuestion())
            case "!":
                return try packageToken(getBang())
            case ">":
                return try packageToken(getIRIRefOrRelational())
            case "|":
                return try packageToken(getOr())
            case "'":
                return try packageToken(getSingleLiteral())
            case "\"":
                return try packageToken(getDoubleLiteral())
            case "_":
                return try packageToken(getBnode())
            case ":":
                return try packageToken(getPName())
            default:
                break
            }
            
            if c == "^" {
                if buffer.hasPrefix("^^") {
                    try read(word: "^^")
                    return packageToken(.hathat)
                } else {
                    try read(word: "^")
                    return packageToken(.hat)
                }
            }
            
            if buffer.hasPrefix("&&") {
                try read(word: "&&")
                return packageToken(.andand)
            }
            
            let bufferLength = NSMakeRange(0, buffer.count)

            let double_range = SPARQLLexer._doubleRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
            if double_range.location == 0 {
                let value = try read(length: double_range.length)
                return packageToken(.double(value))
            }
            
            let decimal_range = SPARQLLexer._decimalRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
            if decimal_range.location == 0 {
                let value = try read(length: decimal_range.length)
                return packageToken(.decimal(value))
            }
            
            let integer_range = SPARQLLexer._integerRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
            if integer_range.location == 0 {
                let value = try read(length: integer_range.length)
                return packageToken(.integer(value))
            }
            
            let token = try getKeyword()
            return packageToken(token)
        }
    }
    
    func getKeyword() throws -> SPARQLToken? {
        let bufferLength = NSMakeRange(0, buffer.count)
        let keyword_range = SPARQLLexer._keywordRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if keyword_range.location == 0 {
            let value = try read(length: keyword_range.length)
            return .keyword(value.uppercased())
        }
        
        let a_range = SPARQLLexer._aRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if a_range.location == 0 {
            try getChar(expecting: "a")
            return .keyword("A")
        }
        
        let bool_range = SPARQLLexer._booleanRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if bool_range.location == 0 {
            let value = try read(length: bool_range.length)
            return .boolean(value.lowercased())
        }
        
        throw lexError("Expecting keyword")
    }
    
    func getVariableOrQuestion() throws -> SPARQLToken? {
        getChar()
        let bufferLength = NSMakeRange(0, buffer.count)
        let variable_range = SPARQLLexer._variableNameRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if variable_range.location == 0 {
            let value = try read(length: variable_range.length)
            return ._var(value)
        } else {
            return .question
//            throw lexError("Expecting variable name")
        }
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    func getSingleLiteral() throws -> SPARQLToken? {
        var chars = [Character]()
        if buffer.hasPrefix("'''") {
            try read(word: "'''")
            var quote_count = 0
            while true {
                if buffer.count == 0 {
                    try fillBuffer()
                    if buffer.count == 0 {
                        if quote_count >= 3 {
                            for _ in 0..<(quote_count-3) {
                                chars.append("'")
                            }
                            return .string3s(String(chars))
                        }
                        throw lexError("Found EOF in string literal")
                    }
                }
                
                guard let c = try peekChar() else {
                    if quote_count >= 3 {
                        for _ in 0..<(quote_count-3) {
                            chars.append("'")
                        }
                        return .string3s(String(chars))
                    }
                    throw lexError("Found EOF in string literal")
                }
                
                if c == "'" {
                    getChar()
                    quote_count += 1
                } else {
                    if quote_count > 0 {
                        if quote_count >= 3 {
                            for _ in 0..<(quote_count-3) {
                                chars.append("'")
                            }
                            return .string3s(String(chars))
                        }
                        for _ in 0..<quote_count {
                            chars.append("'")
                        }
                        quote_count = 0
                    }
                    if c == "\\" {
                        try chars.append(getEscapedChar())
                    } else {
                        chars.append(getChar())
                    }
                }
            }
        } else {
            try getChar(expecting: "'")
            while true {
                if buffer.count == 0 {
                    try fillBuffer()
                    if buffer.count == 0 {
                        throw lexError("Found EOF in string literal")
                    }
                }
                
                guard let c = try peekChar() else {
                    throw lexError("Found EOF in string literal")
                }
                
                if c == "'" {
                    break
                } else if c == "\\" {
                    try chars.append(getEscapedChar())
                } else {
                    let cc = getChar()
                    chars.append(cc)
                }
            }
            try getChar(expecting: "'")
            return .string1s(String(chars))
        }
    }
    
    func getEscapedChar() throws -> Character {
        try getChar(expecting: "\\")
        let c = try getExpectedChar()
        switch c {
        case "r":
            return "\r"
        case "n":
            return "\n"
        case "t":
            return "\t"
        case "\\":
            return "\\"
        case "'":
            return "'"
        case "\"":
            return "\""
        case "u":
            let hex = try read(length: 4)
            guard let codepoint = Int(hex, radix: 16), let s = UnicodeScalar(codepoint) else {
                throw lexError("Invalid unicode codepoint: \(hex)")
            }
            let c = Character(s)
            return c
        case "U":
            let hex = try read(length: 8)
            guard let codepoint = Int(hex, radix: 16), let s = UnicodeScalar(codepoint) else {
                throw lexError("Invalid unicode codepoint: \(hex)")
            }
            let c = Character(s)
            return c
        default:
            throw lexError("Unexpected escape sequence \\\(c)")
        }
    }
    
    func getPName() throws -> SPARQLToken? {
        let bufferLength = NSMakeRange(0, buffer.count)
        let ns_range = SPARQLLexer._pNameNSre.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        guard ns_range.location == 0 else {
            // both the LN and NS branches start with a match of the NS regex, so ensure that it matches first
            return nil
        }

        let ln_range = SPARQLLexer._pNameLNre.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if ln_range.location == 0 {
            var pname = try read(length: ln_range.length)
            if pname.contains("\\") {
                var chars = [Character]()
                var i = pname.makeIterator()
                while let c = i.next() {
                    if c == "\\" {
                        guard let cc = i.next() else { throw lexError("Invalid prefixedname escape") }
                        let escapable = CharacterSet(charactersIn: "_~.-!$&'()*+,;=/?#@%")
                        guard let us = UnicodeScalar("\(cc)"), escapable.contains(us) else {
                            throw lexError("Character cannot be escaped in a prefixedname: '\(cc)'")
                        }
                        chars.append(c)
                    } else {
                        chars.append(c)
                    }
                }
                pname = String(chars)
            }
            
            var values = pname.components(separatedBy: ":")
            if values.count != 2 {
                let pn = values[0]
                let ln = values.suffix(from: 1).joined(separator: ":")
                values = [pn, ln]
            }
            return .prefixname(values[0], values[1])
        } else {
            if ns_range.location == 0 {
                let pname = try read(length: ns_range.length)
                let values = pname.components(separatedBy: ":")
                return .prefixname(values[0], values[1])
            } else {
                return nil
            }
        }
    }
    func getOr() throws -> SPARQLToken? {
        if buffer.hasPrefix("||") {
            try read(word: "||")
            return .oror
        } else {
            try getChar(expecting: "|")
            return .or
        }
    }
    
    func getLanguage() throws -> SPARQLToken? {
        try getChar(expecting: "@")
        let bufferLength = NSMakeRange(0, buffer.count)
        
        let prefixOrBase_range = SPARQLLexer._prefixOrBaseRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        let lang_range = SPARQLLexer._langRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if prefixOrBase_range.location == 0 {
            let value = try read(length: prefixOrBase_range.length)
            return .keyword(value.uppercased())
        } else if lang_range.location == 0 {
            let value = try read(length: lang_range.length)
            return .lang(value.lowercased())
        } else {
            throw lexError("Expecting language")
        }
    }
    
    func getIRIRefOrRelational() throws -> SPARQLToken? {
        let bufferLength = NSMakeRange(0, buffer.count)
        let range = SPARQLLexer._iriRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if range.location == 0 {
            let matchedString = buffer[Range(range, in: buffer)!]
            if matchedString.contains("\\") {
                try getChar(expecting: "<")
                var chars = [Character]()
                while let c = try peekChar() {
                    switch c {
                    case "\\":
                        try chars.append(getEscapedChar())
                    case ">":
                        break
                    default:
                        chars.append(getChar())
                    }
                }
                try getChar(expecting: ">")
                
                let iri = String(chars)
                return .iri(iri)
            } else {
                try getChar(expecting: "<")
                let iri = String(matchedString.dropFirst().dropLast())
                try read(word: iri)
                try getChar(expecting: ">")
                return .iri(iri)
            }
        } else if buffer.hasPrefix("<") {
            try getChar(expecting: "<")
            guard let c = try peekChar() else { throw lexError("Expecting relational expression near EOF") }
            if c == "=" {
                getChar()
                return .le
            } else {
                return .lt
            }
        } else {
            try getChar(expecting: ">")
            guard let c = try peekChar() else { throw lexError("Expecting relational expression near EOF") }
            if c == "=" {
                getChar()
                return .ge
            } else {
                return .gt
            }
        }
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    func getDoubleLiteral() throws -> SPARQLToken? {
        var chars = [Character]()
        if buffer.hasPrefix("\"\"\"") {
            try read(word: "\"\"\"")
            var quote_count = 0
            while true {
                if buffer.count == 0 {
                    try fillBuffer()
                    if buffer.count == 0 {
                        if quote_count >= 3 {
                            for _ in 0..<(quote_count-3) {
                                chars.append("\"")
                            }
                            return .string3d(String(chars))
                        }
                        throw lexError("Found EOF in string literal")
                    }
                }
                
                guard let c = try peekChar() else {
                    if quote_count >= 3 {
                        for _ in 0..<(quote_count-3) {
                            chars.append("\"")
                        }
                        return .string3d(String(chars))
                    }
                    throw lexError("Found EOF in string literal")
                }
                
                if c == "\"" {
                    getChar()
                    quote_count += 1
                } else {
                    if quote_count > 0 {
                        if quote_count >= 3 {
                            for _ in 0..<(quote_count-3) {
                                chars.append("\"")
                            }
                            return .string3d(String(chars))
                        }
                        for _ in 0..<quote_count {
                            chars.append("\"")
                        }
                        quote_count = 0
                    }
                    if c == "\\" {
                        try chars.append(getEscapedChar())
                    } else {
                        chars.append(getChar())
                    }
                }
            }
        } else {
            try getChar(expecting: "\"")
            while true {
                if buffer.count == 0 {
                    try fillBuffer()
                    if buffer.count == 0 {
                        throw lexError("Found EOF in string literal")
                    }
                }
                
                guard let c = try peekChar() else {
                    throw lexError("Found EOF in string literal")
                }
                
                if c == "\"" {
                    break
                } else if c == "\\" {
                    try chars.append(getEscapedChar())
                } else {
                    let cc = getChar()
                    chars.append(cc)
                }
            }
            try getChar(expecting: "\"")
            return .string1d(String(chars))
        }
    }
    
    func getBnode() throws -> SPARQLToken? {
        try read(word: "_:")
        let bufferLength = NSMakeRange(0, buffer.count)
        let bnode_range = SPARQLLexer._bnodeNameRegex.rangeOfFirstMatch(in: buffer, options: [.anchored], range: bufferLength)
        if bnode_range.location == 0 {
            let value = try read(length: bnode_range.length)
            return .bnode(value)
        } else {
            throw lexError("Expecting blank node name")
        }
    }
    
    func getBang() throws -> SPARQLToken? {
        if buffer.hasPrefix("!=") {
            try read(word: "!=")
            return .notequals
        } else {
            try getChar(expecting: "!")
            return .bang
        }
    }
    
    func peekChar() throws -> Character? {
        if let c = buffer.first {
            return c
        } else {
            try fillBuffer()
            return buffer.first
        }
    }
    
    @discardableResult
    func getChar() -> Character {
        let c = buffer.first!
        buffer = String(buffer.dropFirst())
//        buffer = String(buffer[buffer.index(buffer.startIndex, offsetBy: 1)...])
        self.character += 1
        if c == "\n" {
            self.line += 1
            self.column = 1
        } else {
            self.column += 1
        }
        return c
    }
    
    @discardableResult
    func getExpectedChar() throws -> Character {
        guard let c = buffer.first else {
            throw lexError("Unexpected EOF")
        }
        buffer = String(buffer.dropFirst())
//        buffer = String(buffer[buffer.index(buffer.startIndex, offsetBy: 1)...])
        self.character += 1
        if c == "\n" {
            self.line += 1
            self.column = 1
        } else {
            self.column += 1
        }
        return c
    }
    
    @discardableResult
    func getChar(expecting: Character) throws -> Character {
        let c = getChar()
        guard c == expecting else {
            throw lexError("Expecting '\(expecting)' but got '\(c)'")
        }
        return c
    }
    
    func getCharFillBuffer() throws -> Character? {
        try fillBuffer()
        guard buffer.count > 0 else { return nil }
        let c = buffer.first!
        buffer = String(buffer.dropFirst())
//        buffer = String(buffer[buffer.index(buffer.startIndex, offsetBy: 1)...])
        self.character += 1
        if c == "\n" {
            self.line += 1
            self.column = 1
        } else {
            self.column += 1
        }
        return c
    }
    
    func read(word: String) throws {
        try fillBuffer()
        if buffer.count < word.count {
            throw lexError("Expecting '\(word)' but not enough read-ahead data available")
        }
        
        let index = buffer.index(buffer.startIndex, offsetBy: word.count)
        guard buffer.hasPrefix(word) else {
            throw lexError("Expecting '\(word)' but found '\(buffer[..<index])'")
        }
        
        buffer = String(buffer[index...])
        self.character += UInt(word.count)
        for c in word {
            if c == "\n" {
                self.line += 1
                self.column = 1
            } else {
                self.column += 1
            }
        }
    }
    
    @discardableResult
    func read(length: Int) throws -> String {
        try fillBuffer()
        let utf16 = buffer.utf16
        if buffer.utf16.count < length {
            throw lexError("Expecting \(length) characters but not enough read-ahead data available")
        }
        
        let index = utf16.index(utf16.startIndex, offsetBy: length)
        guard let s = String(utf16[..<index]) else {
            throw lexError("Invalid utf16 sequence found while reading bytes")
        }
        guard let b = String(utf16[index...]) else {
            throw lexError("Invalid utf16 sequence found while reading bytes")
        }
        buffer = b
        self.character += UInt(length)
        for c in s {
            if c == "\n" {
                self.line += 1
                self.column = 1
            } else {
                self.column += 1
            }
        }
        return s
    }

    public static func matchingDelimiterRange(for origRange: Range<String.Index>, in string: String) throws -> Range<String.Index>? {
        let acceptable = Set(["]", "}", ")"])
        let delimiter = String(string[origRange])
        guard acceptable.contains(delimiter) else {
            // TODO: this code only allows finding the opening delimiter to match a closing delimiter;
            //       ideally we could find the balancing delimiter in either direction...
            return nil
        }
        
        guard let data = string.data(using: .utf8) else { throw SPARQLSyntaxError.lexicalError("Cannot encode string as utf-8") }

        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        
        var stack = [PositionedToken]()
        let endBound = string.distance(from: string.startIndex, to: origRange.upperBound)
        while let t = lexer.nextPositionedToken() {
            if Int(t.endCharacter) > endBound {
                return nil
            }
            
            switch t.token {
            case .lparen, .lbrace, .lbracket:
                stack.append(t)
            case .rparen, .rbrace, .rbracket:
                guard let poppedToken = stack.popLast() else {
                    throw lexer.lexError("Found unexpected closing \(t.token)")
                }
                switch (t.token, poppedToken.token) {
                case (.rparen, .lparen), (.rbrace, .lbrace), (.rbracket, .lbracket):
                    break
                default:
                    throw lexer.lexError("Closing delimiter \(t.token) didn't match type of opening delimiter \(poppedToken.token)")
                }
                
                let candidateStart = string.index(string.startIndex, offsetBy: Int(poppedToken.startCharacter))
                let endLowerBound = string.index(string.startIndex, offsetBy: Int(t.startCharacter))
                if origRange.lowerBound == endLowerBound {
                    let next = string.index(after: candidateStart)
                    return candidateStart..<next
                }
            default:
                break
            }
        }
        return nil
    }
    
    public static func balancedRange(containing range: Range<String.Index>, in string: String, level: Int = 0) throws -> Range<String.Index> {
        guard let data = string.data(using: .utf8) else { throw SPARQLSyntaxError.lexicalError("Cannot encode string as utf-8") }
        let stream = InputStream(data: data)
        stream.open()
        let lexer = SPARQLLexer(source: stream)
        
        
        var stack = [PositionedToken]()
        let empty = string.startIndex..<string.startIndex
        var balance = empty
        var depth = level
        let start = range.lowerBound
        let end = range.upperBound

        while let t = lexer.nextPositionedToken() {
            let tokenEnd = string.index(string.startIndex, offsetBy: Int(t.endCharacter))
            switch t.token {
            case .lparen, .lbrace, .lbracket:
                stack.append(t)
            case .rparen, .rbrace, .rbracket:
                guard let poppedToken = stack.popLast() else {
                    throw lexer.lexError("Found unexpected closing \(t.token)")
                }
                var ok = false
                switch (t.token, poppedToken.token) {
                case (.rparen, .lparen), (.rbrace, .lbrace), (.rbracket, .lbracket):
                    ok = true
                default:
                    break
                }
                
                if !ok {
                    throw lexer.lexError("Closing delimiter \(t.token) didn't match type of opening delimiter \(poppedToken.token)")
                }
                
                let candidateStart = string.index(string.startIndex, offsetBy: Int(poppedToken.startCharacter))
                let candidateEnd = tokenEnd
                let candidate = candidateStart..<candidateEnd
                if !(candidateStart == range.lowerBound && candidateEnd == range.upperBound) {
                    if start >= candidateStart && end <= tokenEnd {
                        balance = candidate
                        if depth <= 0 {
                            return balance
                        }
                        depth -= 1
                    }
                }
            default:
                break
            }
        }
        return balance
    }
}
