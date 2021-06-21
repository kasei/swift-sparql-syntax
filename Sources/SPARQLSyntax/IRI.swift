//
//  IRI.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 5/22/18.
//

import Foundation
import serd

@dynamicMemberLookup
public struct Namespace {
    public static var xsd = Namespace(value: "http://www.w3.org/2001/XMLSchema#")
    public static var rdf = Namespace(value: "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
    public static var rdfs = Namespace(value: "http://www.w3.org/2000/01/rdf-schema#")
    public static var sd = Namespace(value: "http://www.w3.org/ns/sparql-service-description#")
    public static var hydra = Namespace(value: "http://www.w3.org/ns/hydra/core#")
    public static var void = Namespace(value: "http://rdfs.org/ns/void#")
    public static var formats = Namespace(value: "http://www.w3.org/ns/formats/")
    
    var value: String
    public subscript(dynamicMember member: String) -> String {
        return value.appending(member)
    }
    
    public func iriString(for local: String) -> String {
        let v = value.appending(local)
        return v
    }
    
    public func iri(for local: String) -> IRI? {
        return IRI(string: iriString(for: local))
    }
    
    public init(value: String) {
        self.value = value
    }
    
    public init(url: URL) {
        self.value = url.absoluteString
    }
}

public class IRI : Codable {
    public let absoluteString: String

    convenience public init?(string: String) {
        self.init(string: string, relativeTo: nil)
    }
    
    public init?(fileURLWithPath path: String) {
        do {
            var uri = SERD_URI_NULL
            absoluteString = try withUnsafeMutablePointer(to: &uri) { (u) throws -> String in
                let uu = UnsafeMutablePointer<SerdURI>(u)
                var data = path.data(using: .utf8)!
                var node = try data.withUnsafeMutableBytes { (bp : UnsafeMutableRawBufferPointer) -> SerdNode in
                    guard let p = bp.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        throw IRIError.encodingError("Failed to bind IRI memory to expected type")
                    }
                    return serd_node_new_file_uri(p, nil, uu, false)
                }
                defer {
                    withUnsafeMutablePointer(to: &node) { (n) in
                        serd_node_free(n)
                    }
                }
                let absolute = try u.pointee.value()
                return absolute
            }
        } catch {
            print("IRI error: \(error)")
            return nil
        }
    }
    
    public init?(string: String, relativeTo iri: IRI?) {
        if let iri = iri {
            let baseString = iri.absoluteString
            var rel = SERD_URI_NULL
//            print("<\(iri.absoluteString ?? "")> + <\(string)>")
            let absolute = withUnsafeMutablePointer(to: &rel) { (r) -> String? in
                guard var stringData = string.cString(using: .utf8) else { return nil }
                return stringData.withUnsafeMutableBytes { (bytes) -> String? in
                    guard let stringPtr = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                    let status = serd_uri_parse(stringPtr, r)
                    guard status == SERD_SUCCESS else { return nil }
//                    try? print("Relative IRI: <\(r.pointee.value())>")
                    var base = SERD_URI_NULL
                    return withUnsafeMutablePointer(to: &base) { (b) -> String? in
                        guard var baseData = baseString.cString(using: .utf8) else { return nil }
                        return baseData.withUnsafeMutableBytes { (baseBytes) -> String? in
                            guard let basePtr = baseBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                            let status = serd_uri_parse(basePtr, b)
                            guard status == SERD_SUCCESS else { return nil }
//                            try? print("Base IRI: <\(b.pointee.value())>")
                            var uri = SERD_URI_NULL
                            return withUnsafeMutablePointer(to: &uri) { (out) -> String? in
                                let rr = UnsafePointer(r)
                                let bb = UnsafePointer(b)
                                serd_uri_resolve(rr, bb, out)
                                let absolute = try? out.pointee.value()
                                return absolute
                            }
                        }
                    }
                }
            }
            
            if let a = absolute {
                absoluteString = a
            } else {
                return nil
            }
        } else {
            do {
                var uri = SERD_URI_NULL
                let absolute = try withUnsafeMutablePointer(to: &uri) { (u) throws -> String? in
                    guard var stringData = string.cString(using: .utf8) else { return nil }
                    return try stringData.withUnsafeMutableBytes { (bytes) throws -> String? in
                        guard let stringPtr = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                        let status = serd_uri_parse(stringPtr, u)
                        if status == SERD_SUCCESS {
                            return try u.pointee.value()
                        } else {
                            return nil
                        }
                    }
                }
                if let a = absolute {
                    absoluteString = a
                } else {
                    return nil
                }
            } catch {
                print("IRI error: \(error)")
                return nil
            }
        }
    }
    
    public var url : URL? {
        return URL(string: absoluteString)
    }
}

@dynamicMemberLookup
public struct TermNamespace {
    public var namespace: Namespace
    public init(namespace: Namespace) {
        self.namespace = namespace
    }
    
    public subscript(dynamicMember member: String) -> Term {
        let i = namespace.iriString(for: member)
        return Term(iri: i)
    }
}

@dynamicMemberLookup
public struct NodeNamespace {
    public var namespace: Namespace
    public init(namespace: Namespace) {
        self.namespace = namespace
    }
    
    public subscript(dynamicMember member: String) -> Node {
        let i = namespace.iriString(for: member)
        return .bound(Term(iri: i))
    }
}

public enum IRIError : Error {
    case encodingError(String)
}

fileprivate extension SerdChunk {
    var defined : Bool {
        if let _ = self.buf {
            return true
        } else {
            return false
        }
    }
    
    func value() throws -> String {
        if let buf = self.buf {
            var data = Data()
            data.append(buf, count: self.len)
            guard let string = String(data: data, encoding: .utf8) else {
                throw IRIError.encodingError("Failed to turn \(self.len) bytes from SerdChunk into string: <\(data)>")
            }
            return string
        } else {
            return ""
        }
    }
}

fileprivate extension SerdURI {
    func value() throws -> String {
        var value = ""
        value += try self.scheme.value()
        value += ":"
        if self.authority.defined {
            value += "//"
        }
        value += try self.authority.value()
        value += try self.path_base.value()
        value += try self.path.value()
        let query = try self.query.value()
        if query.count > 0 {
            value += "?"
            value += try self.query.value()
        }
        value += try self.fragment.value()
        return value
    }
}
