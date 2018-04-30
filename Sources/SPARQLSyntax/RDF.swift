import Foundation

public enum TermType {
    case blank
    case iri
    case language(String)
    case datatype(String)
}

extension TermType {
    // swiftlint:disable:next variable_name
    public func resultType(for op: String, withOperandType rhs: TermType) -> TermType? {
        let integer = TermType.datatype("http://www.w3.org/2001/XMLSchema#integer")
        let decimal = TermType.datatype("http://www.w3.org/2001/XMLSchema#decimal")
        let float   = TermType.datatype("http://www.w3.org/2001/XMLSchema#float")
        let double  = TermType.datatype("http://www.w3.org/2001/XMLSchema#double")
        if op == "/" {
            if self == rhs && self == integer {
                return decimal
            }
        }
        switch (self, rhs) {
        case (let a, let b) where a == b:
            return a
        case (integer, decimal), (decimal, integer):
            return decimal
        case (integer, float), (float, integer), (decimal, float), (float, decimal):
            return float
        case (integer, double), (double, integer), (decimal, double), (double, decimal):
            return double
        default:
            return nil
        }
    }
}

extension TermType: Equatable {
    public static func == (lhs: TermType, rhs: TermType) -> Bool {
        switch (lhs, rhs) {
        case (.iri, .iri), (.blank, .blank):
            return true
        case (.language(let l), .language(let r)):
            return l == r
        case (.datatype(let l), .datatype(let r)):
            return l == r
        default:
            return false
        }
    }
}

extension TermType: Hashable {
    public var hashValue: Int {
        switch self {
        case .blank:
            return 0
        case .iri:
            return 1
        case .datatype(let d):
            return 2 ^ d.hashValue
        case .language(let l):
            return 3 ^ l.hashValue
        }
    }
}

public struct Term: CustomStringConvertible, Encodable {
    public var value: String
    public var type: TermType
    public var _doubleValue: Double?
    
    internal func floatingPointComponents() -> (Double, Int) {
        let eIndex = value.index(of: "E") ?? value.endIndex // value is uppercased for xsd:float and xsd:double in computeNumericValue()
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
    
    private mutating func computeNumericValue() {
        switch type {
        case .datatype("http://www.w3.org/2001/XMLSchema#integer"):
            _doubleValue = Double(value) ?? 0.0
        case .datatype("http://www.w3.org/2001/XMLSchema#decimal"):
            let (sign, v, bytes) = canonicalDecimalComponents()
            let frac = bytes.compactMap { "\($0)" }.joined(separator: "")
            let signChar = (sign == .minus) ? "-" : ""
            self.value = "\(signChar)\(v).\(frac)"
            _doubleValue = Double(value) ?? 0.0
        case .datatype("http://www.w3.org/2001/XMLSchema#float"),
             .datatype("http://www.w3.org/2001/XMLSchema#double"):
            self.value = self.value.uppercased()
            let (mantissa, exponent) = canonicalFloatingPointComponents()
            self.value = "\(mantissa)E\(exponent)"
            _doubleValue = Double(value) ?? 0.0
        default:
            break
        }
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
    
    public init(iri value: String) {
        self.value  = value
        self.type   = .iri
    }
    
    public init(string value: String) {
        self.value  = value
        self.type   = .datatype("http://www.w3.org/2001/XMLSchema#string")
    }
    
    public init(boolean value: Bool) {
        self.value = value ? "true" : "false"
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#boolean")
    }
    
    public init(integer value: Int) {
        self.value = "\(value)"
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#integer")
        computeNumericValue()
    }
    
    public init(float value: Double) {
        self.value = String(format: "%E", value)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#float")
        computeNumericValue()
    }
    
    public init(float mantissa: Double, exponent: Int) {
        self.value = String(format: "%fE%d", mantissa, exponent)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#float")
        computeNumericValue()
    }
    
    public init(double value: Double) {
        self.value = String(format: "%E", value)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#double")
        computeNumericValue()
    }
    
    public init(double mantissa: Double, exponent: Int) {
        self.value = String(format: "%lfE%d", mantissa, exponent)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#double")
        computeNumericValue()
    }
    
    public init(decimal value: Double) {
        self.value = String(format: "%f", value)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#decimal")
        computeNumericValue()
    }
    
    public init(decimal value: Decimal) {
        self.value = "\(value)"
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#decimal")
        computeNumericValue()
    }
    
    public init(year: Int, month: Int, day: Int) {
        self.value = String(format: "%04d-%02d-%02d", year, month, day)
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#date")
    }
    
    public init(year: Int, month: Int, day: Int, hours: Int, minutes: Int, seconds: Double, offset: Int) {
        var v = String(format: "%04d-%02d-%02dT%02d:%02d:%02g", year, month, day, hours, minutes, seconds)
        if offset == 0 {
            v = "\(v)Z"
        } else {
            let hours = offset / 60
            let minutes = offset % 60
            v = String(format: "\(v)%+03d:%02d", hours, minutes)
        }
        self.value = v
        self.type = .datatype("http://www.w3.org/2001/XMLSchema#dateTime")
    }
    
    public init?(numeric value: Double, type: TermType) {
        self.type = type
        switch type {
        case .datatype("http://www.w3.org/2001/XMLSchema#float"),
             .datatype("http://www.w3.org/2001/XMLSchema#double"):
            self.value = "\(value)"
        case .datatype("http://www.w3.org/2001/XMLSchema#decimal"):
            self.value = String(format: "%f", value)
        case .datatype("http://www.w3.org/2001/XMLSchema#integer"):
            let i = Int(value)
            self.value = "\(i)"
        default:
            return nil
        }
        computeNumericValue()
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
            let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"@\(lang)"
        case .datatype("http://www.w3.org/2001/XMLSchema#string"):
            let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\""
        case .datatype("http://www.w3.org/2001/XMLSchema#float"):
            let s = "\(value)"
            if s.contains("e") {
                return s
            } else {
                return "\(s)e0"
            }
        case .datatype("http://www.w3.org/2001/XMLSchema#integer"), .datatype("http://www.w3.org/2001/XMLSchema#decimal"), .datatype("http://www.w3.org/2001/XMLSchema#boolean"):
            return "\(value)"
        case .datatype(let dt):
            let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
            return "\"\(escaped)\"^^<\(dt)>"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case language = "xml:lang"
        case datatype = "datatype"
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
            try container.encode(dt, forKey: .datatype)
        case .language(let lang):
            try container.encode("literal", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(lang, forKey: .language)
        }
    }
    
    public static let trueValue = Term(value: "true", type: .datatype("http://www.w3.org/2001/XMLSchema#boolean"))
    public static let falseValue = Term(value: "false", type: .datatype("http://www.w3.org/2001/XMLSchema#boolean"))
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
    public static func == (lhs: Term, rhs: Term) -> Bool {
        if lhs.isNumeric && rhs.isNumeric {
            return lhs.numericValue == rhs.numericValue
        }
        switch (lhs.type, rhs.type) {
        case (.iri, .iri), (.blank, .blank):
            return lhs.value == rhs.value
        case (.language(let l), .language(let r)) where l == r:
            return lhs.value == rhs.value
        case (.datatype(let l), .datatype(let r)) where l == r:
            return lhs.value == rhs.value
        default:
            return false
        }
    }
}

extension Term {
    public var isNumeric: Bool {
        switch type {
        case .datatype("http://www.w3.org/2001/XMLSchema#integer"),
             .datatype("http://www.w3.org/2001/XMLSchema#decimal"),
             .datatype("http://www.w3.org/2001/XMLSchema#float"),
             .datatype("http://www.w3.org/2001/XMLSchema#double"):
            return true
        default:
            return false
        }
    }
    
    public var numeric: NumericValue? {
        switch type {
        case .datatype("http://www.w3.org/2001/XMLSchema#integer"):
            if let i = Int(value) {
                return .integer(i)
            } else {
                return nil
            }
        case .datatype("http://www.w3.org/2001/XMLSchema#decimal"):
            return .decimal(Decimal(numericValue))
        case .datatype("http://www.w3.org/2001/XMLSchema#float"):
            let (mantissa, exponent) = canonicalFloatingPointComponents()
            return .float(mantissa: mantissa, exponent: exponent)
        case .datatype("http://www.w3.org/2001/XMLSchema#double"):
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

extension Term: Hashable {
    public var hashValue: Int {
        return self.value.hashValue
    }
}

public struct Triple: CustomStringConvertible {
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
}

extension Triple: Sequence {
    public func makeIterator() -> IndexingIterator<[Term]> {
        return [subject, predicate, object].makeIterator()
    }
}

public struct Quad: CustomStringConvertible {
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
    public var description: String {
        return "\(subject) \(predicate) \(object) \(graph) ."
    }
}

extension Quad: Sequence {
    public func makeIterator() -> IndexingIterator<[Term]> {
        return [subject, predicate, object, graph].makeIterator()
    }
}

public enum Node {
    case bound(Term)
    case variable(String, binding: Bool)
    
    func bind(_ variable: String, to replacement: Node) -> Node {
        switch self {
        case .variable(variable, _):
            return replacement
        default:
            return self
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
}

extension Node: Equatable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        switch (lhs, rhs) {
        case (.bound(let l), .bound(let r)) where l == r:
            return true
        case (.variable(let l, _), .variable(let r, _)) where l == r:
            return true
        default:
            return false
        }
    }
}