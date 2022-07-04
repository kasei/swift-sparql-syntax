//
//  main.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax

enum CLIError : Error {
    case error(String)
}

func string(fromFileOrString qfile: String) throws -> (String, String?) {
    let url = URL(fileURLWithPath: qfile)
    let string: String
    var base: String? = nil
    if case .some(true) = try? url.checkResourceIsReachable() {
        string = try String(contentsOf: url)
        base = url.absoluteString
    } else {
        string = qfile
    }
    return (string, base)
}

func usage() {
    let args = CommandLine.arguments
    guard let pname = args.first else { fatalError("Missing command name") }
    print("Usage: \(pname) [FLAGS] query.rq")
    print("")
    print("Flags:")
    print("  -c    Read queries from standard input (one per line)")
    print("  -d    URL-decode the query before parsing")
    print("  -l    Use a concise, one-line output format for the query")
    print("")
    exit(1)
}

func run() throws {
    var args = Array(CommandLine.arguments.dropFirst())
    
    var benchmark = false
    var stdin = false
    var pretty = true
    var unescape = false
    var onePerLine = false
    
    while !args.isEmpty && args[0].hasPrefix("-") {
        let f = args.remove(at: 0)
        if f == "--" { break }

        switch f {
        case "-b":
            benchmark = true
        case "-c":
            stdin = true
            onePerLine = true
        case "-l":
            pretty = false
        case "-d":
            unescape = true
        case "--help":
            usage()
        default:
            break
        }
    }

    let unescapeQuery : (String) throws -> String = unescape ? {
        let sparql = $0.replacingOccurrences(of: "+", with: " ")
        if let s = sparql.removingPercentEncoding {
            return s
        } else {
            let e = CLIError.error("Failed to URL percent decode SPARQL query")
            throw e
        }
        } : { $0 }

    if stdin || args.isEmpty {
        let s = SPARQLSerializer(prettyPrint: pretty)
        if onePerLine {
            while let line = readLine() {
                let sparql = try unescapeQuery(line)
                let l = s.reformat(sparql)
                print(l)
            }
        } else {
            var sparql = ""
            while let line = readLine() {
                sparql += line
            }
            let l = s.reformat(sparql)
            print(l)
        }
    } else if let arg = args.first {
        let s = SPARQLSerializer(prettyPrint: pretty)
        let (query, _) = try string(fromFileOrString: arg)
        let max = benchmark ? 100_000 : 1
        for _ in 0..<max {
            let sparql = try unescapeQuery(query)
            let l = s.reformat(sparql)
            print(l)
        }
    }
}

try run()
