//
//  SPARQLSyntax.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 5/25/18.
//

import Foundation

public enum SPARQLSyntaxError: Error, CustomStringConvertible {
    case lexicalError(String)
    case parsingError(String)
    case serializationError(String)
    case unimplemented(String)
    
    public var localizedDescription : String {
        return self.description
    }
    
    public var description : String {
        switch self {
        case .lexicalError(let s):
            return s
        case .parsingError(let s):
            return s
        case .serializationError(let s):
            return s
        case .unimplemented(let s):
            return "Unimplemented: \(s)"
        }
    }
}

