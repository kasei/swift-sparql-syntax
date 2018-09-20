//
//  IRI.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 5/22/18.
//

import Foundation
import serd

public class IRI : Codable {
    public let absoluteString: String

    public init?(string: String) {
        do {
            var uri = SERD_URI_NULL
            let absolute = try withUnsafeMutablePointer(to: &uri) { (u) throws -> String? in
                guard let stringData = string.cString(using: .utf8) else { return nil }
                return try stringData.withUnsafeBytes { (bytes) throws -> String? in
                    let stringPtr = bytes.bindMemory(to: UInt8.self)
                    let status = serd_uri_parse(stringPtr.baseAddress, u)
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
    
    public init?(fileURLWithPath path: String) {
        do {
            var uri = SERD_URI_NULL
            absoluteString = try withUnsafeMutablePointer(to: &uri) { (u) throws -> String in
                let uu = UnsafeMutablePointer<SerdURI>(u)
                let data = path.data(using: .utf8)!
                var node = data.withUnsafeBytes { (s) in
                    serd_node_new_file_uri(s, nil, uu, false)
                }
                let absolute = try u.pointee.value()
                withUnsafeMutablePointer(to: &node) { (n) in
                    serd_node_free(n)
                }
                return absolute
            }
        } catch {
            print("IRI error: \(error)")
            return nil
        }
    }
    
    public init?(string: String, relativeTo iri: IRI?) {
        let baseString = iri?.absoluteString ?? ""
        var rel = SERD_URI_NULL
//        print("<\(iri?.absoluteString ?? "")> + <\(string)>")
        let absolute = withUnsafeMutablePointer(to: &rel) { (r) -> String? in
            guard let stringData = string.cString(using: .utf8) else { return nil }
            return stringData.withUnsafeBytes { (bytes) -> String? in
                let stringPtr = bytes.bindMemory(to: UInt8.self)
                let status = serd_uri_parse(stringPtr.baseAddress, r)
                guard status == SERD_SUCCESS else { return nil }
//                print("Relative IRI: \(r.pointee.value)")
                var base = SERD_URI_NULL
                return withUnsafeMutablePointer(to: &base) { (b) -> String? in
                    guard let baseData = baseString.data(using: .utf8) else { return nil }
                    return baseData.withUnsafeBytes { (basePtr : UnsafePointer<UInt8>) -> String? in
                        let status = serd_uri_parse(basePtr, b)
                        guard status == SERD_SUCCESS else { return nil }
//                        print("Base IRI: \(b.pointee.value)")
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
    }
    
    public var url : URL? {
        return URL(string: absoluteString)
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
