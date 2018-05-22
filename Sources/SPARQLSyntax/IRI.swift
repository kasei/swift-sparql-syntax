//
//  IRI.swift
//  SPARQLSyntax
//
//  Created by Gregory Todd Williams on 5/22/18.
//

import Foundation
import serd

public class IRI {
    let absoluteString: String

    public init?(string: String) {
        var uri = SERD_URI_NULL
        let absolute = withUnsafeMutablePointer(to: &uri) { (u) -> String? in
            let data = string.data(using: .utf8)!
            let status = data.withUnsafeBytes { (s) in
                return serd_uri_parse(s, u)
            }
            if status == SERD_SUCCESS {
                return u.pointee.value
            } else {
                return nil
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
        let absolute = withUnsafeMutablePointer(to: &rel) { (r) -> String? in
            let data = string.data(using: .utf8)!
            let status = data.withUnsafeBytes { (s) in
                return serd_uri_parse(s, r)
            }
            if status != SERD_SUCCESS {
                return nil
            }
            var base = SERD_URI_NULL
            return withUnsafeMutablePointer(to: &base) { (b) -> String? in
                let data = baseString.data(using: .utf8)!
                let status = data.withUnsafeBytes { (s) in
                    return serd_uri_parse(s, b)
                }
                if status != SERD_SUCCESS {
                    return nil
                }
                var uri = SERD_URI_NULL
                return withUnsafeMutablePointer(to: &uri) { (out) -> String? in
                    let rr = UnsafePointer(r)
                    let bb = UnsafePointer(b)
                    serd_uri_resolve(rr, bb, out)
                    let absolute = out.pointee.value
                    return absolute
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
            let len = self.len
            let value = String(cString: buf)
            if value.utf8.count != len {
                let bytes = value.utf8.prefix(len)
                if let string = String(bytes) {
                    return string
                } else {
                    fatalError("Failed to turn \(bytes.count) bytes from SerdChunk into string")
                }
            } else {
                return value
            }
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
