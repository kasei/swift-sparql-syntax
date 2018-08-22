//
//  main.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax

func data(fromFileOrString qfile: String) throws -> (Data, String?) {
    let url = URL(fileURLWithPath: qfile)
    let data: Data
    var base: String? = nil
    if case .some(true) = try? url.checkResourceIsReachable() {
        data = try Data(contentsOf: url)
        base = url.absoluteString
    } else {
        guard let s = qfile.data(using: .utf8) else {
            fatalError("Could not interpret SPARQL query string as UTF-8")
        }
        data = s
    }
    return (data, base)
}

let argscount = CommandLine.arguments.count
var args = CommandLine.arguments
guard let pname = args.first else { fatalError("Missing command name") }
if argscount == 1 {
    print("Usage: \(pname) [FLAGS] query.rq")
    print("")
    print("Flags:")
    print("  -c    Use a concise, one-line output format for the query")
    print("  -d    URL-decode the query before parsing")
    print("")
    exit(1)
}
guard let qfile = args.last else { fatalError("Missing query") }

var pretty = true
var unescape = false
for f in args.dropFirst() {
    guard f.hasPrefix("-") else { break }
    if f == "--" { break }

    switch f {
    case "-c":
        pretty = false
    case "-d":
        unescape = true
    default:
        break
    }
}

let (d, _) = try data(fromFileOrString: qfile)
guard var sparql = String(data: d, encoding: .utf8) else { fatalError("Could not interpret SPARQL query string as UTF-8") }
if unescape {
    sparql = sparql.replacingOccurrences(of: "+", with: " ")
    if let s = sparql.removingPercentEncoding {
        sparql = s
    } else {
        fatalError("Failed to URL percent decode SPARQL query")
    }
}
let s = SPARQLSerializer(prettyPrint: pretty)
let l = s.reformat(sparql)
print(l)
