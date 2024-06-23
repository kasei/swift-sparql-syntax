//
//  PropertyPath.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 8/28/18.
//

import Foundation

public indirect enum PropertyPath: Sendable, Hashable, Equatable {
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

extension PropertyPath : Comparable {
    public static func < (lhs: PropertyPath, rhs: PropertyPath) -> Bool {
        switch (lhs, rhs) {
        case let (.link(l), .link(r)):
            return l < r
        case let (.inv(l), .inv(r)), let (.plus(l), .plus(r)), let (.star(l), .star(r)), let (.zeroOrOne(l), .zeroOrOne(r)):
            return l < r
        case let (.seq(ll, lr), .seq(rl, rr)), let (.alt(ll, lr), .alt(rl, rr)):
            if ll < rl { return true }
            if ll == rl && lr < rr { return true }
            return false
        case let (.nps(l), .nps(r)):
            for (li, ri) in zip(l, r) {
                if li < ri { return true }
                if li > ri { return false }
            }
            return false
        case (.link, _):
            return true
        case (.inv, .nps), (.inv, .alt), (.inv, .seq), (.inv, .plus), (.inv, .star), (.inv, .zeroOrOne):
            return true
        case (.nps, .alt), (.nps, .seq), (.nps, .plus), (.nps, .star), (.nps, .zeroOrOne):
            return true
        case (.alt, .seq), (.alt, .plus), (.alt, .star), (.alt, .zeroOrOne):
            return true
        case (.seq, .plus), (.seq, .star), (.seq, .zeroOrOne):
            return true
        case (.plus, .star), (.plus, .zeroOrOne):
            return true
        case (.star, .zeroOrOne):
            return true
        default:
            return true
        }
    }
}
