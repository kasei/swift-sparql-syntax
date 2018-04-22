import XCTest

import SPARQLParserTests

var tests = [XCTestCaseEntry]()
tests += SPARQLParserTests.allTests()
XCTMain(tests)