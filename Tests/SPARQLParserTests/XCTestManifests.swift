import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SPARQLParserTests.allTests),
        testCase(RDFTests.allTests),
        testCase(AlgebraTests.allTests),
    ]
}
#endif
