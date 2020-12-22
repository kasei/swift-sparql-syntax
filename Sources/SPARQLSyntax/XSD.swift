//
//  XSD.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 4/5/18.
//  Copyright © 2018 Gregory Todd Williams. All rights reserved.
//

import Foundation

public enum NumericValue: CustomStringConvertible, Equatable, Hashable {
    case integer(Int)
    case decimal(Decimal)
    case float(mantissa: Double, exponent: Int)
    case double(mantissa: Double, exponent: Int)
    
    public var value: Double {
        switch self {
        case .integer(let value):
            return Double(value)
        case .decimal(let d):
            return NSDecimalNumber(decimal:d).doubleValue
        //            return Double(truncating: d as NSNumber)
        case .float(let mantissa, let exponent), .double(let mantissa, let exponent):
            return mantissa * pow(10.0, Double(exponent))
        }
    }
    
    public var absoluteValue: NumericValue {
        if value >= 0.0 {
            return self
        } else {
            return self * .integer(-1)
        }
    }
    
    public var round: NumericValue {
        var v = value
        v.round(.toNearestOrAwayFromZero)
        switch self {
        case .decimal(var decimal):
            #if os(macOS)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &decimal, 0, .plain)
            return .decimal(rounded)
            #else
            return .decimal(Decimal(v)) // might lose precision
            #endif
        case .float:
            return .float(mantissa: v, exponent: 0)
        case .double:
            return .double(mantissa: v, exponent: 0)
        default:
            return self
        }
    }
    
    public var ceil: NumericValue {
        var v = value
        v.round(.up)
        switch self {
        case .decimal:
            return .decimal(Decimal(v))
        case .float:
            return .float(mantissa: v, exponent: 0)
        case .double:
            return .float(mantissa: v, exponent: 0)
        default:
            return self
        }
    }
    
    public var floor: NumericValue {
        var v = value
        v.round(.down)
        switch self {
        case .decimal:
            return .decimal(Decimal(v))
        case .float:
            return .float(mantissa: v, exponent: 0)
        case .double:
            return .double(mantissa: v, exponent: 0)
        default:
            return self
        }
    }
    
    public var term: Term {
        switch self {
        case .integer(let value):
            return Term(integer: value)
        case .float:
            return Term(float: value)
        case .decimal:
            return Term(decimal: value)
        case .double:
            return Term(double: value)
        }
    }
    
    public var description: String {
        switch self {
        case .integer(let i):
            return "\(i)"
        case .decimal(let value):
            return "\(value)"
        case let .float(m, e):
            return "\(m)E\(e)f"
        case let .double(m, e):
            return "\(m)E\(e)d"
        }
    }
    
    public static func += (lhs: inout NumericValue, rhs: NumericValue) {
        lhs = lhs + rhs
    }
    
    public static func -= (lhs: inout NumericValue, rhs: NumericValue) {
        lhs = lhs - rhs
    }
    
    public static func + (lhs: NumericValue, rhs: NumericValue) -> NumericValue {
        let value = lhs.value + rhs.value
        return nonDivResultingNumeric(value, lhs, rhs)
    }
    
    public static func - (lhs: NumericValue, rhs: NumericValue) -> NumericValue {
        let value = lhs.value - rhs.value
        return nonDivResultingNumeric(value, lhs, rhs)
    }
    
    public static func * (lhs: NumericValue, rhs: NumericValue) -> NumericValue {
        let value = lhs.value * rhs.value
        return nonDivResultingNumeric(value, lhs, rhs)
    }
    
    public static func / (lhs: NumericValue, rhs: NumericValue) -> NumericValue {
        let value = lhs.value / rhs.value
        return divResultingNumeric(value, lhs, rhs)
    }
    
    public static prefix func - (num: NumericValue) -> NumericValue {
        switch num {
        case .integer(let value):
            return .integer(-value)
        case .decimal(let value):
            return .decimal(-value)
        case .float(let mantissa, let exponent):
            return .float(mantissa: -mantissa, exponent: exponent)
        case .double(let mantissa, let exponent):
            return .double(mantissa: -mantissa, exponent: exponent)
        }
    }
}

public extension NumericValue {
    static func === (lhs: NumericValue, rhs: NumericValue) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let l), .integer(let r)) where l == r:
            return true
        case (.decimal(let l), .decimal(let r)) where l == r:
            return true
        case let (.float(lm, le), .float(rm, re)) where lm == rm && le == re:
            return true
        case let (.double(lm, le), .double(rm, re)) where lm == rm && le == re:
            return true
        default:
            return false
        }
    }
}

private func nonDivResultingNumeric(_ value: Double, _ lhs: NumericValue, _ rhs: NumericValue) -> NumericValue {
    switch (lhs, rhs) {
    case (.integer, .integer):
        return .integer(Int(value))
    case (.decimal, .decimal):
        return .decimal(Decimal(value))
    case (.float, .float):
        return .float(mantissa: value, exponent: 0)
    case (.double, .double):
        return .double(mantissa: value, exponent: 0)
    case (.integer, .decimal), (.decimal, .integer):
        return .decimal(Decimal(value))
    case (.integer, .float), (.float, .integer), (.decimal, .float), (.float, .decimal):
        return .float(mantissa: value, exponent: 0)
    default:
        return .double(mantissa: value, exponent: 0)
    }
}

private func divResultingNumeric(_ value: Double, _ lhs: NumericValue, _ rhs: NumericValue) -> NumericValue {
    switch (lhs, rhs) {
    case (.integer, .integer), (.decimal, .decimal):
        return .decimal(Decimal(value))
    case (.float, .float):
        return .float(mantissa: value, exponent: 0)
    case (.double, .double):
        return .double(mantissa: value, exponent: 0)
    case (.integer, .decimal), (.decimal, .integer):
        return .decimal(Decimal(value))
    case (.integer, .float), (.float, .integer), (.decimal, .float), (.float, .decimal):
        return .float(mantissa: value, exponent: 0)
    default:
        return .double(mantissa: value, exponent: 0)
    }
}

