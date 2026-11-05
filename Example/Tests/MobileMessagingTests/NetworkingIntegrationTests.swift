//
//  NetworkingIntegrationTests.swift
//  MobileMessagingTests
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

// MARK: - MockURLProtocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - NetworkingIntegrationTests

/// Integration tests that exercise the real `DynamicBaseUrlHTTPSessionManager.getDataResponse()` path
/// using `MockURLProtocol` to intercept requests. 
class NetworkingIntegrationTests: XCTestCase {

    private let testBaseURL = URL(string: "https://test.example.com")!

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.lastRequest = nil
        // Clear any stored dynamic base URL from previous tests to avoid cross-test leaks
        UserDefaults.standard.removeObject(forKey: "com.mobile-messaging.dynamic-base-url")
        UserDefaults.standard.synchronize()
    }

    private func makeSessionManager() -> DynamicBaseUrlHTTPSessionManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return DynamicBaseUrlHTTPSessionManager(
            baseURL: testBaseURL,
            sessionConfiguration: config,
            appGroupId: nil
        )
    }

    private func jsonResponse(statusCode: Int = 200, json: [String: Any] = [:], url: URL? = nil, extraHeaders: [String: String] = [:]) -> (HTTPURLResponse, Data?) {
        var headers = ["Content-Type": "application/json"]
        extraHeaders.forEach { headers[$0] = $1 }
        let response = HTTPURLResponse(
            url: url ?? testBaseURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        let data = try? JSONSerialization.data(withJSONObject: json)
        return (response, data)
    }

    // MARK: - Test 1: POST with both JSON body AND query params

    func testPostRequestHasBothJsonBodyAndQueryParams() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["result": "ok"])
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .post,
            path: .AppInstance_Cxxx,
            body: ["deviceToken": "abc123"],
            parameters: ["rt": true]
        )

        sessionManager.getDataResponse(request, queue: .main) { json, error in
            // Verify the intercepted request
            guard let sentRequest = MockURLProtocol.lastRequest else {
                XCTFail("No request was intercepted")
                expectation.fulfill()
                return
            }

            // Verify HTTP method
            XCTAssertEqual(sentRequest.httpMethod, "POST")

            // Verify query params are on the URL with bool as numeric
            let urlString = sentRequest.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("rt=1"), "Expected rt=1 in URL query, got: \(urlString)")

            // Verify JSON body
            if let bodyData = sentRequest.httpBody ?? sentRequest.httpBodyStream?.readAllData() {
                let bodyJson = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
                XCTAssertEqual(bodyJson?["deviceToken"] as? String, "abc123")
            } else {
                XCTFail("POST request should have a JSON body")
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 2: Bool query param encodes as 1/0

    func testBoolQueryParamsEncodeAsNumeric() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["ok": true])
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .get,
            path: .AppInstance_xRUD,
            parameters: ["rt": true, "ri": false],
            pathParameters: ["{pushRegistrationId}": "testPushRegId"]
        )

        sessionManager.getDataResponse(request, queue: .main) { _, _ in
            guard let sentRequest = MockURLProtocol.lastRequest else {
                XCTFail("No request was intercepted")
                expectation.fulfill()
                return
            }

            let urlString = sentRequest.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("rt=1"), "Bool true should encode as 1, got URL: \(urlString)")
            XCTAssertTrue(urlString.contains("ri=0"), "Bool false should encode as 0, got URL: \(urlString)")
            XCTAssertFalse(urlString.contains("rt=true"), "Bool should not encode as 'true'")
            XCTAssertFalse(urlString.contains("ri=false"), "Bool should not encode as 'false'")

            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 3: Request headers include expected fields

    func testRequestHeadersIncludeExpectedFields() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["ok": true])
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .get,
            path: .BaseURL
        )

        sessionManager.getDataResponse(request, queue: .main) { _, _ in
            guard let sentRequest = MockURLProtocol.lastRequest else {
                XCTFail("No request was intercepted")
                expectation.fulfill()
                return
            }

            XCTAssertEqual(sentRequest.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(sentRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNotNil(sentRequest.value(forHTTPHeaderField: "Authorization"), "Authorization header should be set")

            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 4: Non-JSON Content-Type is rejected

    func testNonJsonContentTypeIsRejected() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html"]
            )!
            let data = "<html><body>Error</body></html>".data(using: .utf8)
            return (response, data)
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .get,
            path: .BaseURL
        )

        sessionManager.getDataResponse(request, queue: .main) { json, error in
            XCTAssertNotNil(error, "Non-JSON Content-Type should produce an error")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 5: Valid JSON response succeeds

    func testValidJsonResponseSucceeds() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["status": "ok", "value": 42])
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .get,
            path: .BaseURL
        )

        sessionManager.getDataResponse(request, queue: .main) { json, error in
            XCTAssertNil(error, "Valid JSON response should not produce an error")
            XCTAssertNotNil(json, "Should receive parsed JSON")
            XCTAssertEqual(json?["status"].string, "ok")
            XCTAssertEqual(json?["value"].int, 42)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 6: Server error JSON is parsed into MMRequestError

    func testServerErrorJsonIsParsed() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        let errorJson: [String: Any] = [
            "requestError": [
                "serviceException": [
                    "messageId": "INVALID_VALUE",
                    "text": "Bad request: invalid parameter"
                ]
            ]
        ]

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(statusCode: 400, json: errorJson)
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .post,
            path: .AppInstance_Cxxx,
            body: ["invalid": "data"]
        )

        sessionManager.getDataResponse(request, queue: .main) { json, error in
            XCTAssertNotNil(error, "400 response should produce an error")
            if let error = error {
                XCTAssertEqual(error.domain, "com.mobile-messaging.backend",
                    "Error should be from backend domain, got: \(error.domain)")
                XCTAssertEqual(error.userInfo[Consts.APIKeys.errorText] as? String, "Bad request: invalid parameter")
                XCTAssertEqual(error.userInfo[Consts.APIKeys.errorMessageId] as? String, "INVALID_VALUE")
                XCTAssertEqual(error.mm_httpStatusCode, 400)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 7: 204 No Content handled correctly

    func test204NoContentHandledCorrectly() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (response, nil)
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .post,
            path: .SeenMessages,
            body: ["messageIds": ["msg1"]]
        )

        sessionManager.getDataResponse(request, queue: .main) { json, error in
            // 204 is a success status - should not error
            // Note: json may be nil for empty responses, which is fine
            XCTAssertNil(error, "204 No Content should not produce an error, got: \(String(describing: error))")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Inbox: delete with repeated messageId and 204 No Content

    func testInboxDeleteSendsRepeatedMessageIdsAndHandles204() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: [:])!
            return (response, nil)
        }

        remoteApiProvider.deleteInboxMessages(applicationCode: "testAppCode", accessToken: "jwt", externalUserId: "user1", messageIds: ["legacy+a", "b,c", "d e"], queue: .main) { result in
            XCTAssertNil(result.error, "204 No Content should be a successful delete, got: \(String(describing: result.error))")

            let request = MockURLProtocol.lastRequest!
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/mobile/1/user/user1/inbox/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt")
            XCTAssertNil(request.httpBody)
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.percentEncodedQuery,
                           "messageId=legacy%2Ba&messageId=b,c&messageId=d%20e")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testInboxFetchDecodesNextCursor() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["messages": [], "countTotal": 25, "countUnread": 2, "nextCursor": "eyJ2IjoxfQ"], url: request.url)
        }

        remoteApiProvider.getInbox(applicationCode: "testAppCode", accessToken: nil, externalUserId: "user1", from: nil, to: nil, limit: 20, topic: nil, cursor: "c1", queue: .main) { result in
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.nextCursor, "eyJ2IjoxfQ")
            XCTAssertEqual(result.value?.countTotal, 25)

            let query = URLComponents(url: MockURLProtocol.lastRequest!.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(query.first(where: { $0.name == "cursor" })?.value, "c1")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testEmptyBodyGatewayErrorHasNoServerCode() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: "HTTP/1.1", headerFields: [:])!
            return (response, nil)
        }

        remoteApiProvider.deleteInboxMessages(applicationCode: "testAppCode", accessToken: "jwt", externalUserId: "user1", messageIds: ["a"], queue: .main) { result in
            let error = result.error
            XCTAssertEqual(error?.domain, "com.mobile-messaging.http")
            XCTAssertEqual(error?.code, 502)
            XCTAssertNil(error?.mm_code)
            XCTAssertEqual(error?.mm_httpStatusCode, 502)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testInboxServerErrorKeepsHttpStatusAndServerCode() {
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)

        for (status, messageId) in [(401, "UNAUTHORIZED"), (403, "FORBIDDEN"), (429, "TOO_MANY_REQUESTS")] {
            let expectation = expectation(description: messageId)
            MockURLProtocol.requestHandler = { request in
                return self.jsonResponse(statusCode: status, json: ["requestError": ["serviceException": ["messageId": messageId, "text": "error text"]]], url: request.url)
            }
            remoteApiProvider.deleteInboxMessages(applicationCode: "testAppCode", accessToken: "jwt", externalUserId: "user1", messageIds: ["a"], queue: .main) { result in
                let error = result.error
                XCTAssertEqual(error?.domain, "com.mobile-messaging.backend")
                XCTAssertEqual(error?.mm_code, messageId)
                XCTAssertEqual(error?.mm_httpStatusCode, status)
                expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }
    }

    func testPartialServerErrorBodyKeepsWhatIsPresent() {
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)
        let cases: [(serviceException: [String: Any], domain: String, code: String?, description: String)] = [
            (["messageId": "INVALID_CURSOR"], "com.mobile-messaging.backend", "INVALID_CURSOR", "INVALID_CURSOR"),
            // Real body from the API for a mismatched appCode header: the server omits a null text.
            (["messageId": "NO_APPLICATION"], "com.mobile-messaging.backend", "NO_APPLICATION", "NO_APPLICATION"),
            (["messageId": "INVALID_CURSOR", "text": " "], "com.mobile-messaging.backend", "INVALID_CURSOR", "INVALID_CURSOR"),
            (["text": "Cursor is invalid"], "com.mobile-messaging.http", nil, "Cursor is invalid"),
            (["messageId": " ", "text": "Cursor is invalid"], "com.mobile-messaging.http", nil, "Cursor is invalid"),
            ([:], "com.mobile-messaging.http", nil, "Request failed with status code 400")
        ]

        for testCase in cases {
            let expectation = expectation(description: "\(testCase.serviceException)")
            MockURLProtocol.requestHandler = { request in
                return self.jsonResponse(statusCode: 400, json: ["requestError": ["serviceException": testCase.serviceException]], url: request.url)
            }
            remoteApiProvider.getInbox(applicationCode: "testAppCode", accessToken: nil, externalUserId: "user1", from: nil, to: nil, limit: nil, topic: nil, cursor: "bad", queue: .main) { result in
                let error = result.error
                XCTAssertEqual(error?.domain, testCase.domain, "\(testCase.serviceException)")
                XCTAssertEqual(error?.mm_code, testCase.code, "\(testCase.serviceException)")
                XCTAssertEqual(error?.localizedDescription, testCase.description, "\(testCase.serviceException)")
                XCTAssertEqual(error?.mm_httpStatusCode, 400, "\(testCase.serviceException)")
                if testCase.domain == "com.mobile-messaging.http" {
                    XCTAssertEqual(error?.code, 400)
                }
                expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }
    }

    func testNetworkErrorHasNoHttpStatus() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()
        let remoteApiProvider = RemoteAPIProvider(sessionManager: sessionManager)

        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }

        remoteApiProvider.deleteInboxMessages(applicationCode: "testAppCode", accessToken: "jwt", externalUserId: "user1", messageIds: ["a"], queue: .main) { result in
            XCTAssertEqual(result.error?.domain, NSURLErrorDomain)
            XCTAssertNil(result.error?.mm_httpStatusCode)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 8: New-Base-URL header triggers URL update

    func testNewBaseUrlHeaderTriggersUpdate() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()
        let newBaseUrl = "https://new.example.com"

        XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, testBaseURL.absoluteString)

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(
                json: ["ok": true],
                extraHeaders: [Consts.DynamicBaseUrl.newBaseUrlHeader: newBaseUrl]
            )
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .get,
            path: .BaseURL
        )

        sessionManager.getDataResponse(request, queue: .main) { _, _ in
            XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, newBaseUrl,
                "Dynamic base URL should be updated from response header")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Test 9: Slash un-escaping in JSON body

    func testSlashUnescapingInJsonBody() {
        let expectation = expectation(description: "completion")
        let sessionManager = makeSessionManager()

        MockURLProtocol.requestHandler = { request in
            return self.jsonResponse(json: ["ok": true])
        }

        let request = RequestData(
            applicationCode: "testAppCode",
            method: .post,
            path: .AppInstance_Cxxx,
            body: ["callbackUrl": "https://example.com/callback/path"]
        )

        sessionManager.getDataResponse(request, queue: .main) { _, _ in
            guard let sentRequest = MockURLProtocol.lastRequest,
                  let bodyData = sentRequest.httpBody ?? sentRequest.httpBodyStream?.readAllData() else {
                XCTFail("POST request should have body data")
                expectation.fulfill()
                return
            }

            let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
            XCTAssertTrue(bodyString.contains("https://example.com/callback/path"),
                "JSON body should contain unescaped slashes, got: \(bodyString)")
            XCTAssertFalse(bodyString.contains("https:\\/\\/example.com\\/callback\\/path"),
                "JSON body should NOT contain escaped slashes")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}

// MARK: - InputStream helper

private extension InputStream {
    func readAllData() -> Data {
        open()
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
            close()
        }
        while hasBytesAvailable {
            let read = self.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
