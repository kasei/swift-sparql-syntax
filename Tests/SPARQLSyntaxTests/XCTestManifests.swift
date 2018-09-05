import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AlgebraTests.allTests),
        testCase(IRITests.allTests),
        testCase(RDFTests.allTests),
        testCase(SPARQLParserTests.allTests),
        testCase(SPARQLReformattingTests.allTests),
        testCase(SPARQLRewritingTests.allTests),
        testCase(SPARQLSerializationTests.allTests),
    ]
}
#endif
