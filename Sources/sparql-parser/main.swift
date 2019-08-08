//
//  main.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax

public struct PeekableIterator<T: IteratorProtocol> : IteratorProtocol {
    public typealias Element = T.Element
    private var generator: T
    private var bufferedElement: Element?
    public  init(generator: T) {
        self.generator = generator
        bufferedElement = self.generator.next()
    }
    
    public mutating func next() -> Element? {
        let r = bufferedElement
        bufferedElement = generator.next()
        return r
    }
    
    public func peek() -> Element? {
        return bufferedElement
    }
    
    mutating func dropWhile(filter: (Element) -> Bool) {
        while bufferedElement != nil {
            if !filter(bufferedElement!) {
                break
            }
            _ = next()
        }
    }
    
    mutating public func elements() -> [Element] {
        var elements = [Element]()
        while let e = next() {
            elements.append(e)
        }
        return elements
    }
}

func getCurrentDateSeconds() -> UInt64 {
    var startTime: time_t
    startTime = time(nil)
    return UInt64(startTime)
}

func warn(_ items: String...) {
    for string in items {
        fputs(string, stderr)
        fputs("\n", stderr)
    }
}

func printSPARQL(_ data: Data, pretty: Bool = false, silent: Bool = false, includeComments: Bool = false) throws {
    guard let sparql = String(data: data, encoding: .utf8) else {
        fatalError("Failed to decode SPARQL query as utf8")
    }
    let s = SPARQLSerializer(prettyPrint: pretty)
    print(s.reformat(sparql))
}

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

func ok_prefix_for_special_variables(_ vars: Set<String>) -> String {
    let count = vars.map { (v) in v.prefix(while: { $0 == "_" }).count }.reduce(0, max)
    let prefix = String(repeating: "_", count: count+1)
    return prefix
}

func special_variable_rewrite_map(_ vars: Set<String>) -> [String:Term] {
    let prefix = ok_prefix_for_special_variables(vars)
    var map = [String:Term]()
    for v in vars {
        if v.hasPrefix(".") {
            let newName = prefix + v.suffix(from: v.index(v.startIndex, offsetBy: 1))
            map[v] = Term(value: newName, type: .blank)
        }
    }
    return map
}

var verbose = true
let argscount = CommandLine.arguments.count
var args = PeekableIterator(generator: CommandLine.arguments.makeIterator())
guard let pname = args.next() else { fatalError("Missing command name") }
guard argscount > 2 else {
    print("Usage: \(pname) [-v] COMMAND [ARGUMENTS]")
    print("       \(pname) parse query.rq")
    print("       \(pname) lint query.rq")
    print("       \(pname) tokens query.rq")
    print("       \(pname) wikidata query.rq")
    print("")
    exit(1)
}

if let next = args.peek(), next == "-v" {
    _ = args.next()
    verbose = true
}

let startSecond = getCurrentDateSeconds()
var count = 0

if let op = args.next() {
    if op == "parse" || op == "wikidata" {
        var printAlgebra = false
        var printSPARQL = false
        var pretty = true
        if let next = args.peek(), next.lowercased() == "-s" {
            _ = args.next()
            printSPARQL = true
            if next == "-S" {
                pretty = true
            }
        }
        if let next = args.peek(), next == "-a" {
            _ = args.next()
            printAlgebra = true
        }
        if !printAlgebra && !printSPARQL {
            printAlgebra = true
        }
        
        guard let qfile = args.next() else { fatalError("No query file given") }
        do {
            let (sparqldata, base) = try data(fromFileOrString: qfile)
            var sparql = sparqldata
            if op == "wikidata" {
                let prefixes = """
                    PREFIX wd: <http://www.wikidata.org/entity/>
                    PREFIX wds: <http://www.wikidata.org/entity/statement/>
                    PREFIX wdv: <http://www.wikidata.org/value/>
                    PREFIX wdt: <http://www.wikidata.org/prop/direct/>
                    PREFIX wikibase: <http://wikiba.se/ontology#>
                    PREFIX p: <http://www.wikidata.org/prop/>
                    PREFIX ps: <http://www.wikidata.org/prop/statement/>
                    PREFIX pq: <http://www.wikidata.org/prop/qualifier/>
                    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                    PREFIX bd: <http://www.bigdata.com/rdf#>

                    PREFIX wdref: <http://www.wikidata.org/reference/>
                    PREFIX psv: <http://www.wikidata.org/prop/statement/value/>
                    PREFIX psn: <http://www.wikidata.org/prop/statement/value-normalized/>
                    PREFIX pqv: <http://www.wikidata.org/prop/qualifier/value/>
                    PREFIX pqn: <http://www.wikidata.org/prop/qualifier/value-normalized/>
                    PREFIX pr: <http://www.wikidata.org/prop/reference/>
                    PREFIX prv: <http://www.wikidata.org/prop/reference/value/>
                    PREFIX prn: <http://www.wikidata.org/prop/reference/value-normalized/>
                    PREFIX wdno: <http://www.wikidata.org/prop/novalue/>
                    PREFIX wdata: <http://www.wikidata.org/wiki/Special:EntityData/>

                    PREFIX schema: <http://schema.org/>
                    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                    PREFIX owl: <http://www.w3.org/2002/07/owl#>
                    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
                    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
                    PREFIX prov: <http://www.w3.org/ns/prov#>
                    PREFIX bds: <http://www.bigdata.com/rdf/search#>
                    PREFIX gas: <http://www.bigdata.com/rdf/gas#>
                    PREFIX hint: <http://www.bigdata.com/queryHints#>
                """.data(using: .utf8)!
                sparql = prefixes + sparqldata
            }
            guard var p = SPARQLParser(data: sparql, base: base) else { fatalError("Failed to construct SPARQL parser") }
            if op == "wikidata" {
                p.parseSPARQLStarReificationForWikidata = true
            }
            var query = try p.parseQuery()
            let vars = query.algebra.allVariables
            let rewrite_map = special_variable_rewrite_map(vars)
            query = try query.replace(rewrite_map)
            
            count = 1
            if printAlgebra {
                print(query.serialize())
            }
            if printSPARQL {
                let s = SPARQLSerializer(prettyPrint: pretty)
                let tokens  = try query.sparqlTokens()
                print(s.serialize(tokens))
            }
        } catch let e {
            warn("*** Failed to parse query: \(e)")
        }
    } else if op == "tokens" {
        var printAlgebra = false
        var printSPARQL = false
        if let next = args.peek(), next.lowercased() == "-s" {
            _ = args.next()
            printSPARQL = true
        }
        if let next = args.peek(), next == "-a" {
            _ = args.next()
            printAlgebra = true
        }
        if !printAlgebra && !printSPARQL {
            printAlgebra = true
        }
        
        guard let qfile = args.next() else { fatalError("No query file given") }
        do {
            let (sparql, _) = try data(fromFileOrString: qfile)
            let stream = InputStream(data: sparql)
            stream.open()
            let lexer = SPARQLLexer(source: stream, includeComments: true)
            while let t = lexer.next() {
                print("\(t)")
            }
        } catch let e {
            warn("*** Failed to tokenize query: \(e)")
        }
    } else if op == "lint", let qfile = args.next() {
        do {
            let pretty = true
            let (sparql, _) = try data(fromFileOrString: qfile)
            try printSPARQL(sparql, pretty: pretty, silent: false, includeComments: true)
        } catch let e {
            warn("*** Failed to lint query: \(e)")
        }
    } else {
        warn("Unrecognized operation: '\(op)'")
        exit(1)
    }
}
