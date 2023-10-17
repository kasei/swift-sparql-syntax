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

struct Config {
    var benchmark = false
    var stdin = false
    var pretty = true
    var unescape = false
    var onePerLine = false
    
    func unescape(query : String) throws -> String {
        if unescape {
            let sparql = query.replacingOccurrences(of: "+", with: " ")
            if let s = sparql.removingPercentEncoding {
                return s
            } else {
                let e = CLIError.error("Failed to URL percent decode SPARQL query")
                throw e
            }
        } else {
            return query
        }
    }
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
    exit(0)
}

func reformat(_ sparql: String, config: Config) -> String {
    let s = SPARQLSerializer(prettyPrint: config.pretty)
    return s.reformat(sparql)
}

func parseConfig(_ args: inout [String]) -> Config {
    var config = Config()
    
    while !args.isEmpty && args[0].hasPrefix("-") {
        let f = args.remove(at: 0)
        if f == "--" { break }

        switch f {
        case "-b":
            config.benchmark = true
        case "-c":
            config.stdin = true
            config.onePerLine = true
        case "-l":
            config.pretty = false
        case "-d":
            config.unescape = true
        case "--help":
            usage()
        default:
            break
        }
    }
    return config
}

func run() throws {
    var args = Array(CommandLine.arguments.dropFirst())
    let config = parseConfig(&args)

    if config.stdin || args.isEmpty {
        if config.onePerLine {
            while let line = readLine() {
                let sparql = try config.unescape(query: line)
                print(reformat(sparql, config: config))
            }
        } else {
            var sparql = ""
            while let line = readLine() {
                sparql += line
            }
            print(reformat(sparql, config: config))
        }
    } else if let arg = args.first {
        let (query, _) = try string(fromFileOrString: arg)
        let max = config.benchmark ? 100_000 : 1
        for _ in 0..<max {
            let sparql = try config.unescape(query: query)
            print(reformat(sparql, config: config))
        }
    }
}

do {
    try run()
} catch {
    exit(1)
}
