import Foundation

public protocol RDFSerializer {
    init()
    var canonicalMediaType: String { get }
    func serialize<S: Sequence>(_ triples: S) throws -> Data where S.Element == Triple
    func serialize<T: TextOutputStream, S: Sequence>(_ triples: S, to: inout T) throws where S.Element == Triple
}

public typealias TripleHandler = (Term, Term, Term) -> Void
public protocol RDFParser {
    init()
    var mediaTypes: Set<String> { get }
    func parse(string: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> Int
    func parseFile(_ filename: String, mediaType: String, base: String?, handleTriple: @escaping TripleHandler) throws -> Int
}

