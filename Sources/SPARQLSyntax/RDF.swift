import Foundation

public enum TermDataType: Hashable, ExpressibleByStringLiteral, Comparable {
    case string
    case boolean
    case integer
    case float
    case double
    case decimal
    case date
    case time
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
        case .time:
            return "http://www.w3.org/2001/XMLSchema#time"
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
        case "http://www.w3.org/2001/XMLSchema#time":
            self = .time
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

public struct Term: CustomStringConvertible, Hashable, Codable {
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
                let (mantissa, exponent) = canonicalFloatingPointComponents()
                self.value = "\(mantissa)E\(exponent)"
            }
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
            let hours = offset / 60
            let minutes = offset % 60
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
        case .datatype(.string):
            let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
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
            let escaped = value.replacingOccurrences(of:"\"", with: "\\\"")
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

extension Term {
    public var duration: (months: Int, seconds: Double)? {
        switch type {
        case .datatype(TermDataType(stringLiteral: Namespace.xsd.duration)),
             .datatype(TermDataType(stringLiteral: Namespace.xsd.yearMonthDuration)),
             .datatype(TermDataType(stringLiteral: Namespace.xsd.dayTimeDuration)):
            break
        default:
            return nil
        }
        var neg = false
        var s = value
        if value.hasPrefix("-") {
            neg = true
            s = String(s.dropFirst())
        }
        
        guard s.hasPrefix("P") else {
            return nil
        }
        
        var seconds = 0.0
        var months = 0
        s = String(s.dropFirst())
        guard !s.isEmpty else {
            return nil
        }
        var datePart = true
        while !s.isEmpty {
            let i = s.firstIndex { $0.isLetter } ?? s.endIndex
            let numPart = s.prefix(upTo: i)
            let rest = s.suffix(from: i)
            if numPart.isEmpty {
                guard rest.hasPrefix("T") else {
                    return nil
                }
                datePart = false
                s = String(s.dropFirst())
                guard !s.isEmpty else {
                    return nil
                }
                continue
            }
            guard let dv = Double(String(numPart)) else {
                return nil
            }
            let v = Int(dv)
            guard let c = rest.first else {
                return nil
            }
            // -?nYnMnDTnHnMnS
            switch c {
            case "Y":
                //                print("\(v) years")
                months += v * 12
            case "M" where datePart:
                //                print("\(v) months")
                months += v
            case "D":
                //                print("\(v) days")
                seconds += Double(v * 24*60*60)
            case "H":
                //                print("\(v) hours")
                seconds += Double(v * 60*60)
            case "M":
                //                print("\(v) minutes")
                seconds += Double(v * 60)
            case "S":
                //                print("\(v) seconds")
                seconds += Double(numPart) ?? 0.0
            default:
                print("Unrecognized duration part \(c) in '\(value)'")
                return nil
            }
            s = String(rest.dropFirst())
        }
        if neg {
            months = -months
            seconds = -seconds
        }
        return (months, seconds)
    }
    
    public var dateComponents: DateComponents? {
        switch self.type {
        case .datatype(.time):
            let c = value.split(separator: ":").compactMap { Int(String($0)) }
            guard c.count == 3 else {
                return nil
            }
            return DateComponents(hour: c[0], minute: c[1], second: c[2])
        case .datatype(.date):
            let c = value.split(separator: "-").compactMap { Int(String($0)) }
            guard c.count == 3 else {
                return nil
            }
            return DateComponents(year: c[0], month: c[1], day: c[2])
        case .datatype(.dateTime):
            let parts = value.split(separator: "T")
            let date = parts[0]
            let dc = date.split(separator: "-").compactMap { Int(String($0)) }
            guard dc.count == 3 else {
                return nil
            }
            var components = DateComponents(year: dc[0], month: dc[1], day: dc[2])
            let time = date.prefix(while: { $0 != "-" && $0 != "+" })
            let tc = time.split(separator: ":").compactMap { Int(String($0)) }
            guard tc.count == 3 else {
                return nil
            }
            components.hour = tc[0]
            components.minute = tc[1]
            components.second = tc[2]
            return components
        default:
            return nil
        }
    }
    
    public var isADateType: Bool {
        switch type {
        case .datatype(.date),
             .datatype(.dateTime):
            return true
        default:
            return false
        }
    }
    
    public var isTime: Bool {
        switch type {
        case .datatype(.time):
            return true
        default:
            return false
        }
    }
    
    public var isDuration: Bool {
        switch type {
        case .datatype(.custom("http://www.w3.org/2001/XMLSchema#duration")),
             .datatype(.custom("http://www.w3.org/2001/XMLSchema#yearMonthDuration")),
             .datatype(.custom("http://www.w3.org/2001/XMLSchema#dayTimeDuration")):
            return true
        default:
            return false
        }
    }
}

public struct Triple: Codable, Hashable, CustomStringConvertible {
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

    public var triple: Triple {
        return Triple(subject: subject, predicate: predicate, object: object)
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
    
    func bind(_ variable: String, to replacement: Node) -> Node {
        switch self {
        case .variable(variable, _):
            return replacement
        default:
            return self
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
