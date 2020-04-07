import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(mobile_messaging_sdk_iosTests.allTests),
    ]
}
#endif
