import Foundation

public protocol RDFSerializer {
    init()
    var canonicalMediaType: String { get }
    func serialize<S: Sequence>(_ triples: S) throws -> Data where S.Element == Triple
    func serialize<T: TextOutputStream, S: Sequence>(_ triples: S, to: inout T) throws where S.Element == Triple
}

public protocol PrefixableRDFSerializer {
    var prefixes: [String:Term] { get }
    mutating func add(name: String, for namespace: String)
}

public typealias TripleHandler = (Term, Term, Term) -> Void
public typealias QuadHandler = (Term, Term, Term, Term) -> Void

public protocol RDFPushParser {
    init()
    var mediaTypes: Set<String> { get }
    func parse(string: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> Int
    func parseFile(_ filename: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> Int

    func parse(string: String, mediaType: String, defaultGraph: Term, base: String?, handleQuad: @escaping QuadHandler) throws -> Int
    func parseFile(_ filename: String, mediaType: String, defaultGraph: Term, base: String?, handleQuad: @escaping QuadHandler) throws -> Int
}
public typealias RDFParser = RDFPushParser

public protocol RDFPullParser {
    init()
    var mediaTypes: Set<String> { get }
    func parse(string: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> AnySequence<Triple>
    func parseFile(_ filename: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> AnySequence<Triple>

    func parse(string: String, mediaType: String, defaultGraph: Term, base: String?, handleQuad: @escaping QuadHandler) throws -> AnySequence<Quad>
    func parseFile(_ filename: String, mediaType: String, defaultGraph: Term, base: String?, handleQuad: @escaping QuadHandler) throws -> AnySequence<Quad>
}

