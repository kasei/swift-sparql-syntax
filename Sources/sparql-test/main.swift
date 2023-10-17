//
//  main.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax
import Rainbow

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
    print("  -a    Print the query algebra")
    print("  -c    Read queries from standard input (one per line)")
    print("  -d    URL-decode the query before parsing")
    print("")
    exit(1)
}

func run() throws {
    var args = Array(CommandLine.arguments.dropFirst())
    
    var stdin = false
    var unescape = false
    var onePerLine = false
    var printAlgebra = false
    
    while !args.isEmpty && args[0].hasPrefix("-") {
        let f = args.remove(at: 0)
        if f == "--" { break }

        switch f {
        case "-a":
            printAlgebra = true
        case "-c":
            stdin = true
            onePerLine = true
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
        if onePerLine {
            while let line = readLine() {
                let sparql = try unescapeQuery(line)
                handleQuery(sparql, printAlgebra)
            }
        } else {
            var sparql = ""
            while let line = readLine() {
                sparql += line
            }
            handleQuery(sparql, printAlgebra)
        }
    } else if let arg = args.first {
        let (query, _) = try string(fromFileOrString: arg)
        let sparql = try unescapeQuery(query)
        handleQuery(sparql, printAlgebra)
    }
}

extension SPARQLSerializer {
    public enum HightlightState {
        case normal
        case highlighted
    }
    public typealias Highlighter = (String, HightlightState) -> String
    public typealias HighlighterMap = [Set<ClosedRange<Int>>: (String, Highlighter)]
    public func reformatHighlightingRanges(_ sparql: String, highlighterMap: HighlighterMap) -> (String, Set<String>?) {
        let sparql = prettyPrint ? reformat(sparql) : sparql
        
        // compute the set of tokens (by their token number) that should be highlighted
        var highlightedChars = [(ClosedRange<Int>, String, Highlighter)]()
        for (ranges, highlighterTuple) in highlighterMap {
            var highlightedTokens = Set<Int>()
            for range in ranges {
                for i in range {
                    highlightedTokens.insert(i)
                }
            }
            
            guard let data = sparql.data(using: .utf8) else {
                return (sparql, nil)
            }
            let stream = InputStream(data: data)
            
            // compute the characters in the sparql string that should be highlighted
            stream.open()
            var charRanges = [(Int, ClosedRange<Int>)]()
            do {
                let lexer = try SPARQLLexer(source: stream)
                while let t = try lexer.getToken() {
                    if highlightedTokens.contains(t.tokenNumber) {
                        let range = Int(t.startCharacter)...Int(t.endCharacter)
                        if charRanges.isEmpty {
                            charRanges.append((t.tokenNumber, range))
                        } else {
                            let tuple = charRanges.last!
                            if (tuple.0+1) == t.tokenNumber {
                                // coalesce
                                let tuple = charRanges.removeLast()
                                let r = tuple.1
                                let rr = r.lowerBound...range.upperBound
                                charRanges.append((t.tokenNumber, rr))
                            } else {
                                charRanges.append((t.tokenNumber, range))
                            }
                        }
                    }
                }
            } catch {}
            let name = highlighterTuple.0
            highlightedChars.append(contentsOf: charRanges.map { ($0.1, name, highlighterTuple.1) })
        }
        
        // reverse sort so that we insert color-codes back-to-front and the offsets don't shift underneath us
        // note this will not work if the ranges are overlapping
        highlightedChars.sort { $0.0.lowerBound > $1.0.lowerBound }

        // for each highlighted character range, replace the substring with one that has .red color codes inserted
        var highlighted = sparql
        
        var names = Set<String>()
        for (range, name, highlight) in highlightedChars {
            names.insert(highlight(name, .highlighted))
            // TODO: instead of highlighting by subrange replacement, break the string in to all sub-ranges (both highlighted and non-highlighted)
            // and call the highlighter for all the ranges and just concatenate them to preduce the result.
            let start = sparql.index(sparql.startIndex, offsetBy: range.lowerBound)
            let end = sparql.index(sparql.startIndex, offsetBy: range.upperBound)
            let stringRange = start..<end
            let s = String(highlighted[stringRange])
            let h = highlight(s, .highlighted)
            highlighted.replaceSubrange(stringRange, with: h)
        }
        return (highlighted, names)
    }
}
func makeHighlighter(color: KeyPath<String, String>) -> SPARQLSerializer.Highlighter {
    return { (s, state) in
        if case .highlighted = state {
            return s[keyPath: color]
        } else {
            return s
        }
    }
}

func showHighlightedAlgebra(_ sparql : String, _ printAlgebra: Bool, _ predicate : (Algebra) -> (String, Int)?) throws {
    var parser = SPARQLParser(string: sparql)!
    let q = try parser.parseQuery()
    let a = q.algebra
    
    var names = [Int: String]()
    var highlight = [Int: Set<ClosedRange<Int>>]()
    var algebraToTokens = [Algebra: Set<ClosedRange<Int>>]()
    try a.walk { (algebra) in
        let ranges = parser.getTokenRange(for: algebra)
        
        
        
        // HIGHLIGHT AGGREGATIONS IN THE OUTPUT
        if let tuple = predicate(algebra) {
            let name = tuple.0
            let i = tuple.1
            names[i] = name
            for r in ranges {
                highlight[i, default: []].insert(r)
            }
        }
        
        if ranges.isEmpty {
//            print("*** No range for algebra: \(algebra.serialize())")
//            print("--- \n\(sparql)\n--- \n")
        } else {
            algebraToTokens[algebra] = ranges
        }
    }

    let colors : [KeyPath<String, String>] = [\.red, \.yellow, \.green, \.blue, \.magenta]
    if !highlight.isEmpty {
        let ser = SPARQLSerializer(prettyPrint: true)
        let highlighterMap = Dictionary(uniqueKeysWithValues: highlight.map {
            let name = names[$0.key] ?? "\($0.key)"
            let highlighter = makeHighlighter(color: colors[$0.key % colors.count])
            return ($0.value, (name, highlighter))
        })
//        let highlighterMap : SPARQLSerializer.HighlighterMap = [highlight: makeHighlighter(color: \.red)]
        let (h, names) = ser.reformatHighlightingRanges(sparql, highlighterMap: highlighterMap)
        if let names = names {
            for name in names.sorted() {
                print("- \(name)")
            }
        }
        print("\n\(h)")
        if printAlgebra {
            print(a.serialize())
        }
    }
}


func handleQuery(_ sparql : String, _ printAlgebra: Bool) {
    do {
        guard let data = sparql.data(using: .utf8) else { return }
        let stream = InputStream(data: data)
        stream.open()
        try showHighlightedAlgebra(sparql, printAlgebra) {
            switch $0 {
            case .innerJoin:
                return ("Join", 6)
//            case .bgp, .triple:
//                return ("BGP", 5)
            case .filter:
                return ("Filter", 4)
            case .path:
                return ("Path", 3)
            case .order:
                return ("Sorting", 2)
//            case .leftOuterJoin:
//                return ("Optional", 1)
            case .slice:
                return ("Slicing", 5)
            default:
                return nil
            }
        }
    } catch let e {
        print("*** \(e)")
    }
}

do {
    try run()
} catch let e {
    print("*** \(e)")
}
