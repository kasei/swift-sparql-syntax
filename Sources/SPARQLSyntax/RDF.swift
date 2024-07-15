import Foundation

public enum TermDataType: Hashable, ExpressibleByStringLiteral, Comparable {
    case string
    case boolean
    case integer
    case float
    case double
    case decimal
    case date
    case dateTime
    case custom(String)
    
    public var value: String {
        switch self {
        case .string:
            return "http://www.w3.org/2001/XMLSchema#string"
        case .boolean:
            return "http://www.w3.org/2001/XMLSchema#boolean"
        case .integer:
            return "http://www.w3.org/2001/XMLSchema#integer"
        case .float:
            return "http://www.w3.org/2001/XMLSchema#float"
        case .double:
            return "http://www.w3.org/2001/XMLSchema#double"
        case .decimal:
            return "http://www.w3.org/2001/XMLSchema#decimal"
        case .date:
            return "http://www.w3.org/2001/XMLSchema#date"
        case .dateTime:
            return "http://www.w3.org/2001/XMLSchema#dateTime"
        case .custom(let v):
            return v
        }
    }
   
    public init(stringLiteral value: String) {
        switch value {
        case "http://www.w3.org/2001/XMLSchema#string":
            self = .string
        case "http://www.w3.org/2001/XMLSchema#boolean":
            self = .boolean
        case "http://www.w3.org/2001/XMLSchema#integer":
            self = .integer
        case "http://www.w3.org/2001/XMLSchema#float":
            self = .float
        case "http://www.w3.org/2001/XMLSchema#double":
            self = .double
        case "http://www.w3.org/2001/XMLSchema#decimal":
            self = .decimal
        case "http://www.w3.org/2001/XMLSchema#date":
            self = .date
        case "http://www.w3.org/2001/XMLSchema#dateTime":
            self = .dateTime
        default:
            self = .custom(value)
        }
    }

    public static func < (lhs: TermDataType, rhs: TermDataType) -> Bool {
        return lhs.value < rhs.value
    }
}

public enum TermType {
    case blank
    case iri
    case language(String)
    case datatype(TermDataType)
}

extension TermType {
    // swiftlint:disable:next variable_name
    public var integerType: Bool {
        guard case .datatype(let dt) = self else { return false }
        switch dt.value {
            case "http://www.w3.org/2001/XMLSchema#integer",
                 "http://www.w3.org/2001/XMLSchema#nonPositiveInteger",
                 "http://www.w3.org/2001/XMLSchema#negativeInteger",
                 "http://www.w3.org/2001/XMLSchema#long",
                 "http://www.w3.org/2001/XMLSchema#int",
                 "http://www.w3.org/2001/XMLSchema#short",
                 "http://www.w3.org/2001/XMLSchema#byte",
                 "http://www.w3.org/2001/XMLSchema#nonNegativeInteger",
                 "http://www.w3.org/2001/XMLSchema#unsignedLong",
                 "http://www.w3.org/2001/XMLSchema#unsignedInt",
                 "http://www.w3.org/2001/XMLSchema#unsignedShort",
                 "http://www.w3.org/2001/XMLSchema#unsignedByte",
                 "http://www.w3.org/2001/XMLSchema#positiveInteger":
            return true
        default:
            return false
        }
    }
    
    public func resultType(for op: String, withOperandType rhs: TermType) -> TermType? {
        let integer = TermType.datatype(.integer)
        let decimal = TermType.datatype(.decimal)
        let float   = TermType.datatype(.float)
        let double  = TermType.datatype(.double)
        if op == "/" {
            if self == rhs && self.integerType {
                return decimal
            }
        }
        switch (self, rhs) {
        case (let a, let b) where a == b && a.integerType && b.integerType:
            return integer
        case (let a, let b) where a == b:
            return a
        case (let i, decimal) where i.integerType,
             (decimal, let i) where i.integerType:
            return decimal
        case (let i, float) where i.integerType,
             (float, let i) where i.integerType:
            return float
        case (decimal, float),
             (float, decimal):
            return float
        case (let i, double) where i.integerType,
             (double, let i) where i.integerType:
            return double
        case (decimal, double),
             (double, decimal):
            return double
        case (let a, let b) where a.integerType && b.integerType:
            return integer
        case (_, double),
             (double, _):
            return double
        default:
            return nil
        }
    }
}

extension TermType: Hashable {
    public static func == (lhs: TermType, rhs: TermType) -> Bool {
        switch (lhs, rhs) {
        case (.iri, .iri), (.blank, .blank):
            return true
        case (.language(let l), .language(let r)):
            return l.lowercased() == r.lowercased()
        case (.datatype(let l), .datatype(let r)):
            return l == r
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .language(let l):
            hasher.combine("language")
            hasher.combine(l.lowercased())
        case .datatype(let dt):
            hasher.combine("datatype")
            hasher.combine(dt)
        case .iri:
            hasher.combine("iri")
        case .blank:
            hasher.combine("iri")
        }
    }
}

public struct Term: CustomStringConvertible, CustomDebugStringConvertible, Hashable, Codable {
    public var value: String
    public var type: TermType
    public var _doubleValue: Double?
    
    internal func floatingPointComponents() -> (Double, Int) {
        let eIndex = value.firstIndex(of: "E") ?? value.endIndex // value is uppercased for xsd:float and xsd:double in computeNumericValue()
        let mString = value[..<eIndex]
        let mantissa = Double(mString) ?? 0.0
        var exponent = 0
        if eIndex != value.endIndex {
            let next = value.index(after: eIndex)
            let eString = value[next...]
            exponent = Int(eString) ?? 0
        }
        return (mantissa, exponent)
    }
    
    internal func canonicalFloatingPointComponents() -> (Double, Int) {
        var (mantissa, exponent) = floatingPointComponents()
        if mantissa.isFinite {
            while abs(mantissa) >= 10.0 {
                mantissa /= 10.0
                exponent += 1
            }
            if abs(mantissa) > 0.0 {
                while abs(mantissa) < 1.0 {
                    mantissa *= 10.0
                    exponent -= 1
                }
            }
            if mantissa == 0.0 {
                exponent = 0
            }
        }
        return (mantissa, exponent)
    }
    
    internal func canonicalDecimalComponents() -> (FloatingPointSign, Int, [UInt8]) {
        var parts = value.components(separatedBy: ".")
        var sign : FloatingPointSign = .plus
        if parts[0].hasPrefix("-") {
            sign = .minus
            parts[0] = String(parts[0][parts[0].index(parts[0].startIndex, offsetBy: 1)...])
        }
        let v = Int(parts[0]) ?? 0
        var bytes : [UInt8] = [0]
        if parts.count > 1 {
            let zero = UInt8("0".unicodeScalars.first!.value)
            bytes = Array(parts[1].utf8.map { $0 - zero })
            while bytes.count > 1 && bytes.last! == 0 {
                bytes.removeLast()
            }
        }
        return (sign, v, bytes)
    }
    
    private mutating func computeNumericValue(canonicalize: Bool = true) {
        switch type {
        case let t where t.integerType:
            if canonicalize {
                let c = Int(value) ?? 0
                self.value = "\(c)"
            }
            _doubleValue = Double(value)
        case .datatype(.decimal):
            if canonicalize {
                let (sign, v, bytes) = canonicalDecimalComponents()
                let frac = bytes.compactMap { "\($0)" }.joined(separator: "")
                let signChar = (sign == .minus) ? "-" : ""
                self.value = "\(signChar)\(v).\(frac)"
            }
            _doubleValue = Double(value) ?? 0.0
        case .datatype(.float),
             .datatype(.double):
            if canonicalize {
                self.value = self.value.uppercased()
                if self.value == "INFINITY" || self.value == "INF" {
                    self.value = "INF"
                } else if self.value == "-INFINITY" || self.value == "-INF" {
                    self.value = "-INF"
                } else if self.value == "NAN" {
                    self.value = "NaN"
                } else {
                    let (mantissa, exponent) = canonicalFloatingPointComponents()
                    if mantissa.truncatingRemainder(dividingBy: 1) == 0 {
                        self.value = "\(Int(mantissa))E\(exponent)"
                    } else {
                        self.value = "\(mantissa)E\(exponent)"
                    }
                }
            }
            _doubleValue = Double(value) ?? 0.0
        default:
            break
        }
    }

    private static let _integerPattern: Regex = {
        return #/^[-+]?[0-9]+$/#.anchorsMatchLineEndings()
    }()

    private static let _decimalPattern: Regex = {
        return #/^[-+]?([0-9]+([.][0-9]*)?|[.]\d+)$/#.anchorsMatchLineEndings()
    }()

    private static let _doublePattern: Regex = {
        return #/^[-+]?(\d+([.]\d*)?|[.]\d+)([eE]([-+])?\d+)?$/#.anchorsMatchLineEndings()
    }()

    private static let _boolSet: Set<String> = {
        return Set(["0", "1", "true", "false"])
    }()

    public static func isValidLexicalForm(_ value: String, for type: TermDataType) -> Bool {
        switch type {
        case .string:
            return true
        case .boolean:
            return _boolSet.contains(value)
        case .integer:
            if let _ = try? _integerPattern.prefixMatch(in: value) {
                return true
            } else {
                return false
            }
        case .decimal:
            if let _ = try? _decimalPattern.prefixMatch(in: value) {
                return true
            } else {
                return false
            }
        case .float, .double:
            if let _ = try? _doublePattern.prefixMatch(in: value) {
                return true
            } else {
                return false
            }
        default:
            break
        }
        return false
    }

    public static func rdf(_ local: String) -> Term {
        return Term(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#\(local)", type: .iri)
    }
    
    public static func xsd(_ local: String) -> Term {
        return Term(value: "http://www.w3.org/2001/XMLSchema#\(local)", type: .iri)
    }
    
    public init(value: String, type: TermType) {
        self.value  = value
        self.type   = type
        computeNumericValue()
    }
    
    public init(canonicalValue value: String, type: TermType) {
        self.value  = value
        self.type   = type
        computeNumericValue(canonicalize: false)
    }
    
    public init(iri value: String) {
        self.value  = value
        self.type   = .iri
    }
    
    public init(string value: String) {
        self.value  = value
        self.type   = .datatype(.string)
    }
    
    public init(boolean value: Bool) {
        self.value = value ? "true" : "false"
        self.type = .datatype(.boolean)
    }
    
    public init(integer value: Int) {
        self.value = "\(value)"
        self.type = .datatype(.integer)
        _doubleValue = Double(value)
    }
    
    public init(float value: Double) {
        self.value = String(format: "%E", value)
        self.type = .datatype(.float)
        computeNumericValue()
    }
    
    public init(float mantissa: Double, exponent: Int) {
        self.value = String(format: "%fE%d", mantissa, exponent)
        self.type = .datatype(.float)
        computeNumericValue()
    }
    
    public init(double value: Double) {
        self.value = String(format: "%E", value)
        self.type = .datatype(.double)
        computeNumericValue()
    }
    
    public init(double mantissa: Double, exponent: Int) {
        self.value = String(format: "%lfE%d", mantissa, exponent)
        self.type = .datatype(.double)
        computeNumericValue()
    }
    
    public init(decimal value: Double) {
        self.value = String(format: "%f", value)
        self.type = .datatype(.decimal)
        computeNumericValue()
    }
    
    public init(decimal value: Decimal) {
        self.value = "\(value)"
        self.type = .datatype(.decimal)
        computeNumericValue()
    }
    
    public init(year: Int, month: Int, day: Int) {
        self.value = String(format: "%04d-%02d-%02d", year, month, day)
        self.type = .datatype(.date)
    }

    public init(dateTime date: Date, timeZone tz: TimeZone?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hours = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = Double(calendar.component(.second, from: date))
        if let tz = tz {
            let offset = tz.secondsFromGMT(for: date)
            self.init(year: year, month: month, day: day, hours: hours, minutes: minutes, seconds: seconds, offset: offset)
        } else {
            self.init(year: year, month: month, day: day, hours: hours, minutes: minutes, seconds: seconds, offset: 0)
            value.removeLast() // remove the trailing 'Z'
        }
    }
    
    public init(year: Int, month: Int, day: Int, hours: Int, minutes: Int, seconds: Double, offset: Int) {
        var v = String(format: "%04d-%02d-%02dT%02d:%02d:%02g", year, month, day, hours, minutes, seconds)
        if offset == 0 {
            v = "\(v)Z"
        } else {
            let hours = offset / (60*60)
            let minutes = offset % (60*60)
            v = String(format: "\(v)%+03d:%02d", hours, minutes)
        }
        self.value = v
        self.type = .datatype(.dateTime)
    }
    
    public init?(numeric value: Double, type: TermType) {
        self.type = type
        switch type {
        case .datatype(.float),
             .datatype(.double):
            self.value = "\(value)"
        case .datatype(.decimal):
            self.value = String(format: "%f", value)
        case let t where t.integerType:
            let i = Int(value)
            self.value = "\(i)"
        default:
            return nil
        }
        computeNumericValue()
    }
    
    public static func == (lhs: Term, rhs: Term) -> Bool {
        guard lhs.type == rhs.type else { return false }
        return lhs.value.unicodeScalars.elementsEqual(rhs.value.unicodeScalars)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        for s in value.unicodeScalars {
            hasher.combine(s)
        }
    }

    public var debugDescription: String {
           switch type {
           case .iri:
               return "<\(value)>"
           case .blank:
               return "_:\(value)"
           case .language(let lang):
               let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
               return "\"\(escaped)\"@\(lang)"
           case .datatype(.string):
               let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
               return "\"\(escaped)\"^^xsd:string"
           case .datatype(.float):
               let s = "\(value)"
               if s.lowercased().contains("e") {
                   return s
               } else {
                   return "\"\(s)e0\"^^xsd:float"
               }
           case .datatype(.integer):
               return "\"\(value)\"^^xsd:integer"
           case .datatype(.decimal):
               return "\"\(value)\"^^xsd:decimal"
           case .datatype(.boolean):
               return "\"\(value)\"^^xsd:boolean"
           case .datatype(let dt):
               let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
               return "\"\(escaped)\"^^<\(dt.value)>"
           }
       }
    
    public var description: String {
        switch type {
            //        case .iri where value == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type":
        //            return "a"
        case .iri:
            return "<\(value)>"
        case .blank:
            return "_:\(value)"
        case .language(let lang):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"@\(lang)"
        case .datatype(.string):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\""
        case .datatype(.float):
            let s = "\(value)"
            if s.lowercased().contains("e") {
                return s
            } else {
                return "\(s)e0"
            }
        case .datatype(.integer), .datatype(.decimal), .datatype(.boolean):
            return "\(value)"
        case .datatype(let dt):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"^^<\(dt.value)>"
        }
    }
    
    public var fullDescription: String {
        switch type {
            //        case .iri where value == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type":
        //            return "a"
        case .iri:
            return "<\(value)>"
        case .blank:
            return "_:\(value)"
        case .language(let lang):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"@\(lang)"
        case .datatype(.string):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\""
        case .datatype(.float):
            let s = "\(value)"
            if s.lowercased().contains("e") {
                return "\"\(s)\"^^<\(Namespace.xsd.iriString(for: "float"))>"
            } else {
                return "\"\(s)e0\"^^<\(Namespace.xsd.iriString(for: "float"))>"
            }
        case .datatype(.integer):
            return "\"\(value)\"^^<\(Namespace.xsd.iriString(for: "integer"))>"
        case .datatype(.decimal):
            return "\"\(value)\"^^<\(Namespace.xsd.iriString(for: "decimal"))>"
        case .datatype(.boolean):
            return "\"\(value)\"^^<\(Namespace.xsd.iriString(for: "boolean"))>"
        case .datatype(let dt):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"^^<\(dt.value)>"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case language = "xml:lang"
        case datatype = "datatype"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        switch type {
        case "bnode":
            self.init(value: value, type: .blank)
        case "uri":
            self.init(value: value, type: .iri)
        case "literal":
            if container.contains(.language) {
                let lang = try container.decode(String.self, forKey: .language)
                self.init(value: value, type: .language(lang))
            } else {
                let dt = try container.decode(String.self, forKey: .datatype)
                self.init(value: value, type: .datatype(TermDataType(stringLiteral: dt)))
            }
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected term type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.type {
        case .blank:
            try container.encode("bnode", forKey: .type)
            try container.encode(value, forKey: .value)
        case .iri:
            try container.encode("uri", forKey: .type)
            try container.encode(value, forKey: .value)
        case .datatype(let dt):
            try container.encode("literal", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(dt.value, forKey: .datatype)
        case .language(let lang):
            try container.encode("literal", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(lang, forKey: .language)
        }
    }
    
    public static func boolean(_ value: Bool) -> Term {
        return value ? trueValue : falseValue
    }
    
    public static let trueValue = Term(value: "true", type: .datatype(.boolean))
    public static let falseValue = Term(value: "false", type: .datatype(.boolean))
}

extension Term: Comparable {
    public static func < (lhs: Term, rhs: Term) -> Bool {
        if lhs.isNumeric && rhs.isNumeric {
            return lhs.numericValue < rhs.numericValue
        }
        switch (lhs.type, rhs.type) {
        case (let a, let b) where a == b:
            return lhs.value < rhs.value
        case (.blank, _):
            return true
        case (.iri, .language(_)), (.iri, .datatype(_)):
            return true
        case (.language(_), .datatype(_)):
            return true
        case (.datatype(let l), .datatype(let r)):
            return l < r
        default:
            return false
        }
    }
}

extension Term: Equatable {
    public func equals(_ term: Term) -> Bool {
        if self.isNumeric && term.isNumeric {
            return self.numericValue == term.numericValue
        } else {
            return self == term
        }
    }
}

extension Term {
    public var isNumeric: Bool {
        guard case .datatype(let dt) = type else { return false }
        switch dt.value {
        case "http://www.w3.org/2001/XMLSchema#integer",
             "http://www.w3.org/2001/XMLSchema#nonPositiveInteger",
             "http://www.w3.org/2001/XMLSchema#negativeInteger",
             "http://www.w3.org/2001/XMLSchema#long",
             "http://www.w3.org/2001/XMLSchema#int",
             "http://www.w3.org/2001/XMLSchema#short",
             "http://www.w3.org/2001/XMLSchema#byte",
             "http://www.w3.org/2001/XMLSchema#nonNegativeInteger",
             "http://www.w3.org/2001/XMLSchema#unsignedLong",
             "http://www.w3.org/2001/XMLSchema#unsignedInt",
             "http://www.w3.org/2001/XMLSchema#unsignedShort",
             "http://www.w3.org/2001/XMLSchema#unsignedByte",
             "http://www.w3.org/2001/XMLSchema#positiveInteger":
            return true
        case "http://www.w3.org/2001/XMLSchema#decimal",
             "http://www.w3.org/2001/XMLSchema#float",
             "http://www.w3.org/2001/XMLSchema#double":
            return true
        default:
            return false
        }
    }
    
    public var numeric: NumericValue? {
        switch type {
        case let t where t.integerType:
            if let i = Int(value) {
                return .integer(i)
            } else {
                return nil
            }
        case .datatype(.decimal):
            return .decimal(Decimal(numericValue))
        case .datatype(.float):
            let (mantissa, exponent) = canonicalFloatingPointComponents()
            return .float(mantissa: mantissa, exponent: exponent)
        case .datatype(.double):
            let (mantissa, exponent) = canonicalFloatingPointComponents()
            return .double(mantissa: mantissa, exponent: exponent)
        default:
            return nil
        }
        
    }
    
    public var numericValue: Double {
        return _doubleValue ?? 0.0
    }
}

public struct Triple: Codable, Hashable, CustomStringConvertible {
    public enum Position: String, CaseIterable {
        case subject
        case predicate
        case object
    }

    public var subject: Term
    public var predicate: Term
    public var object: Term
    public init(subject: Term, predicate: Term, object: Term) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }
    public var description: String {
        return "\(subject) \(predicate) \(object) ."
    }

    public var fullDescription: String {
        return "\(subject.fullDescription) \(predicate.fullDescription) \(object.fullDescription) ."
    }
}

extension Triple {
    public subscript(_ position: Triple.Position) -> Term {
        switch position {
        case .subject:
            return self.subject
        case .predicate:
            return self.predicate
        case .object:
            return self.object
        }
    }
}

extension Triple {
    public func replace(_ map: (Term) throws -> Term?) throws -> Triple {
        let terms = self.map { (t) -> Term in
            do {
                if let term = try map(t) {
                    return term
                }
            } catch {}
            return t
        }
        let s = terms[0]
        let p = terms[1]
        let o = terms[2]
        return Triple(subject: s, predicate: p, object: o)
    }
}

extension Triple: Sequence {
    public func makeIterator() -> IndexingIterator<[Term]> {
        return [subject, predicate, object].makeIterator()
    }
}

public struct Quad: Codable, Hashable, CustomStringConvertible {
    public enum Position: String, CaseIterable {
        case subject
        case predicate
        case object
        case graph
    }

    public var subject: Term
    public var predicate: Term
    public var object: Term
    public var graph: Term
    public init(subject: Term, predicate: Term, object: Term, graph: Term) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.graph = graph
    }
    public init(triple: Triple, graph: Term) {
        self.subject = triple.subject
        self.predicate = triple.predicate
        self.object = triple.object
        self.graph = graph
    }
    
    public var description: String {
        return "\(subject) \(predicate) \(object) \(graph) ."
    }

    public var fullDescription: String {
        return "\(subject.fullDescription) \(predicate.fullDescription) \(object.fullDescription) \(graph.fullDescription) ."
    }

    public var triple: Triple {
        return Triple(subject: subject, predicate: predicate, object: object)
    }
}

extension Quad {
    public subscript(_ position: Quad.Position) -> Term {
        switch position {
        case .subject:
            return self.subject
        case .predicate:
            return self.predicate
        case .object:
            return self.object
        case .graph:
            return self.graph
        }
    }
}

extension Quad: Sequence {
    public func makeIterator() -> IndexingIterator<[Term]> {
        return [subject, predicate, object, graph].makeIterator()
    }
}

public enum Node : Equatable, Hashable {
    case bound(Term)
    case variable(String, binding: Bool)
    
    public init(variable name: String) {
        self = .variable(name, binding: true)
    }
    
    public init(term: Term) {
        self = .bound(term)
    }
    
    public func bind(_ variable: String, to replacement: Node) -> Node {
        switch self {
        case .variable(variable, _):
            return replacement
        default:
            return self
        }
    }

    public var isBound: Bool { return !isVariable }
    
    public var isVariable: Bool {
        switch self {
        case .bound:
            return false
        case .variable:
            return true
        }
    }
    
    public var boundTerm: Term? {
        switch self {
        case .bound(let t):
            return t
        case .variable:
            return nil
        }
    }
}

extension Node: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case binding
        case variable
        case term
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "variable":
            let binding = try container.decode(Bool.self, forKey: .binding)
            let name = try container.decode(String.self, forKey: .variable)
            self = .variable(name, binding: binding)
        case "term":
            let term = try container.decode(Term.self, forKey: .term)
            self = .bound(term)
        default:
            throw SPARQLSyntaxError.serializationError("Unexpected node type '\(type)' found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .variable(name, binding: binding):
            try container.encode("variable", forKey: .type)
            try container.encode(name, forKey: .variable)
            try container.encode(binding, forKey: .binding)
        case .bound(let term):
            try container.encode("term", forKey: .type)
            try container.encode(term, forKey: .term)
        }
    }
}

extension Node: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bound(let t):
            return t.description
        case .variable(let name, _):
            return "?\(name)"
        }
    }

    public var fullDescription: String {
        switch self {
        case .bound(let t):
            return t.fullDescription
        case .variable(let name, _):
            return "?\(name)"
        }
    }
}

extension Node {
    func replace(_ map: [String:Term]) throws -> Node {
        switch self {
        case let .variable(name, binding: _):
            if let t = map[name] {
                return .bound(t)
            } else {
                return self
            }
        default:
            return self
        }
    }
}
