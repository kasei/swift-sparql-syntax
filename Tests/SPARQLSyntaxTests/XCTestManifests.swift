import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AlgebraTests.allTests),
        testCase(RDFTests.allTests),
        testCase(SPARQLParserTests.allTests),
        testCase(SPARQLSerializationTests.allTests),
    ]
}
#endif
