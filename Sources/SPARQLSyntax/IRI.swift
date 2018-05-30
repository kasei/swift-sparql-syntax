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
        var uri = SERD_URI_NULL
        let absolute = withUnsafeMutablePointer(to: &uri) { (u) -> String? in
            guard let stringData = string.cString(using: .utf8) else { return nil }
            return stringData.withUnsafeBytes { (bytes) -> String? in
                let stringPtr = bytes.bindMemory(to: UInt8.self)
                let status = serd_uri_parse(stringPtr.baseAddress, u)
                if status == SERD_SUCCESS {
                    return u.pointee.value
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
    }
    
    public init(fileURLWithPath path: String) {
        var uri = SERD_URI_NULL
        absoluteString = withUnsafeMutablePointer(to: &uri) { (u) in
            let uu = UnsafeMutablePointer<SerdURI>(u)
            let data = path.data(using: .utf8)!
            var node = data.withUnsafeBytes { (s) in
                serd_node_new_file_uri(s, nil, uu, false)
            }
            let absolute = u.pointee.value
            withUnsafeMutablePointer(to: &node) { (n) in
                serd_node_free(n)
            }
            return absolute
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
                        return withUnsafeMutablePointer(to: &uri) { (out) -> String in
                            let rr = UnsafePointer(r)
                            let bb = UnsafePointer(b)
                            serd_uri_resolve(rr, bb, out)
                            let absolute = out.pointee.value
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

fileprivate extension SerdChunk {
    var defined : Bool {
        if let _ = self.buf {
            return true
        } else {
            return false
        }
    }
    
    var value : String {
        if let buf = self.buf {
            var data = Data()
            data.append(buf, count: self.len)
            guard let string = String(data: data, encoding: .utf8) else {
                fatalError("Failed to turn \(self.len) bytes from SerdChunk into string")
            }
            return string
        } else {
            return ""
        }
    }
}

fileprivate extension SerdURI {
    var value : String {
        var value = ""
        value += self.scheme.value
        value += ":"
        if self.authority.defined {
            value += "//"
        }
        value += self.authority.value
        value += self.path_base.value
        value += self.path.value
        let query = self.query.value
        if query.count > 0 {
            value += "?"
            value += self.query.value
        }
        value += self.fragment.value
        return value
    }
}
