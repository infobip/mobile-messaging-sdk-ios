//
//  InboxExample/InboxExampleTests/LiveInboxAPITests.swift
//  InboxExampleTests
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import MobileMessaging
import MobileMessagingInbox
@testable import InboxExample

/// Calls a real Infobip environment through the SDK, to see how it parses real server responses.
/// Skipped unless `INBOX_LIVE_APP_CODE`, `INBOX_LIVE_BASE_URL` and `INBOX_LIVE_USER` are set
/// (pass them with the `TEST_RUNNER_` prefix to xcodebuild). Set `INBOX_LIVE_DELETE_ALL=1` to also delete
/// every message of that user in one request.
final class LiveInboxAPITests: XCTestCase {
    private var user = ""
    private var inbox: MMInboxService!

    override func setUp() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let appCode = env["INBOX_LIVE_APP_CODE"], let baseUrl = env["INBOX_LIVE_BASE_URL"], let user = env["INBOX_LIVE_USER"] else {
            throw XCTSkip("Live API environment not configured")
        }
        self.user = user
        let started = await MainActor.run { () -> Bool in
            var settings = AppModel.shared.settings
            settings.applicationCode = appCode
            settings.baseUrl = baseUrl
            settings.authorization = .applicationCode
            AppModel.shared.save(settings)
            return !AppModel.shared.requiresRelaunch
        }
        guard started else {
            throw XCTSkip("The app was started with another Application Code. Run the tests again.")
        }
        // `MobileMessaging.inbox` exists before the SDK has started, and fetching and deleting need a push registration.
        for _ in 0..<300 {
            let ready = await MainActor.run { AppModel.shared.isSdkStarted && MobileMessaging.getInstallation()?.pushRegistrationId != nil }
            if ready {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard await MainActor.run(body: { AppModel.shared.isSdkStarted }) else {
            throw XCTSkip("The SDK did not start")
        }
        guard MobileMessaging.getInstallation()?.pushRegistrationId != nil else {
            throw XCTSkip("No push registration. Run the tests on a device that can register for push notifications.")
        }
        inbox = try XCTUnwrap(MobileMessaging.inbox)
    }

    /// `mm_code` of arguments the SDK rejects before sending a request.
    private static let invalidParameters = "20013"

    // MARK: - Fetch errors

    func testFetchWithInvalidJwt() async {
        await expectError("fetch: garbage JWT", code: "UNAUTHORIZED", status: nil) {
            _ = try await self.inbox.fetchInbox(token: "not.a.jwt", externalUserId: self.user, options: nil)
        }
    }

    func testFetchWithWellFormedButUnsignedJwt() async {
        await expectError("fetch: unsigned JWT", code: "UNAUTHORIZED", status: nil) {
            _ = try await self.inbox.fetchInbox(token: Self.unsignedJwt(sub: self.user), externalUserId: self.user, options: nil)
        }
    }

    func testFetchWithInvalidCursor() async {
        await expectError("fetch: invalid cursor", code: "INVALID_CURSOR", status: nil) {
            _ = try await self.inbox.fetchInbox(externalUserId: self.user, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 1, cursor: "xyz"))
        }
    }

    func testFetchWithUserIdContainingSlash() async {
        await expectError("fetch: externalUserId with '/'", code: nil, status: 400) {
            _ = try await self.inbox.fetchInbox(externalUserId: "a/b", options: nil)
        }
    }

    func testFetchWithTooLongTopic() async {
        await expectError("fetch: 7.4 KB topic", code: nil, status: 431) {
            _ = try await self.inbox.fetchInbox(externalUserId: self.user, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: String(repeating: "x", count: 7400), limit: 1))
        }
    }

    // MARK: - Delete errors

    func testDeleteWithInvalidJwt() async {
        await expectError("delete: garbage JWT", code: "UNAUTHORIZED", status: nil) {
            try await self.inbox.deleteMessages(token: "not.a.jwt", externalUserId: self.user, messageIds: ["x"])
        }
    }

    func testDeleteWithWellFormedButUnsignedJwt() async {
        await expectError("delete: unsigned JWT", code: "UNAUTHORIZED", status: nil) {
            try await self.inbox.deleteMessages(token: Self.unsignedJwt(sub: self.user), externalUserId: self.user, messageIds: ["x"])
        }
    }

    func testDeleteWithUserIdContainingSlash() async {
        await expectError("delete: externalUserId with '/'", code: nil, status: 400) {
            try await self.inbox.deleteMessages(externalUserId: "a/b", messageIds: ["x"])
        }
    }

    func testDeleteWithTooLongQuery() async {
        let ids = (0..<120).map { "\(String(repeating: "x", count: 60))\($0)" }
        await expectError("delete: 120 x 62-char ids (~8.8 KB query)", code: nil, status: nil) {
            try await self.inbox.deleteMessages(externalUserId: self.user, messageIds: ids)
        }
    }

    // MARK: - Local validation (no request is sent)

    func testEmptyDeleteIsRejectedLocally() async {
        await expectError("delete: no ids", code: Self.invalidParameters, status: nil, local: true) {
            try await self.inbox.deleteMessages(externalUserId: self.user, messageIds: [])
        }
    }

    func testBlankIdDeleteIsRejectedLocally() async {
        await expectError("delete: blank id", code: Self.invalidParameters, status: nil, local: true) {
            try await self.inbox.deleteMessages(externalUserId: self.user, messageIds: ["x", " "])
        }
    }

    func testBlankTokenIsRejectedLocally() async {
        await expectError("fetch: blank JWT", code: Self.invalidParameters, status: nil, local: true) {
            _ = try await self.inbox.fetchInbox(token: " ", externalUserId: self.user, options: nil)
        }
    }

    func testCursorWithTopicsIsRejectedLocally() async {
        let options = MMInboxFilterOptions(dictRepresentation: ["topics": ["a", "b"], "cursor": "c1"])
        await expectError("fetch: cursor with topics", code: Self.invalidParameters, status: nil, local: true) {
            _ = try await self.inbox.fetchInbox(externalUserId: self.user, options: options)
        }
    }

    func testDeleteOfMissingMessageSucceeds() async throws {
        try await inbox.deleteMessages(externalUserId: user, messageIds: ["inbox-live-missing-\(UUID().uuidString)"])
        print("LIVE delete: missing id -> success")
    }

    // MARK: - Delete everything

    func testDeleteAllMessagesInOneRequest() async throws {
        guard ProcessInfo.processInfo.environment["INBOX_LIVE_DELETE_ALL"] == "1" else {
            throw XCTSkip("INBOX_LIVE_DELETE_ALL not set")
        }
        let before = try await fetchAll()
        let ids = before.messages.map(\.messageId)
        guard !ids.isEmpty else {
            // The SDK rejects an empty list of message IDs, so there is nothing to delete.
            throw XCTSkip("The inbox of \(user) is empty")
        }
        let query = ids.map { "messageId=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0)" }.joined(separator: "&")
        print("LIVE delete all: before countTotal=\(before.countTotal) unread=\(before.countUnread) ids=\(ids.count) query≈\(query.count) chars")
        let start = Date()
        try await inbox.deleteMessages(externalUserId: user, messageIds: ids)
        print("LIVE delete all: \(ids.count) ids deleted in one request, \(Int(Date().timeIntervalSince(start) * 1000)) ms")

        for attempt in 1...10 {
            let after = try await fetchAll()
            let remaining = Set(after.messages.map(\.messageId)).intersection(ids)
            print("LIVE delete all: fetch #\(attempt) after delete -> countTotal=\(after.countTotal) unread=\(after.countUnread) returned=\(after.messages.count) stillVisibleDeleted=\(remaining.count)")
            // Messages older than the inbox limit can surface once newer ones are deleted, so only the deleted IDs are checked.
            if remaining.isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        XCTFail("Deleted messages still visible after 10 s")
    }

    // MARK: - Helpers

    private func fetchAll() async throws -> MMInbox {
        guard let result = try await inbox.fetchInbox(externalUserId: user, options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 100)) else {
            throw InboxExampleError.emptyResponse
        }
        return result
    }

    /// Runs `body`, prints how the SDK reported the error and checks `mm_code` / HTTP status when given.
    /// A `local` error must have been raised by the SDK without a response, so it has no HTTP status.
    private func expectError(_ name: String, code: String?, status: Int?, local: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ body: @escaping () async throws -> Void) async {
        do {
            try await body()
            print("LIVE \(name) -> unexpected success")
            XCTFail("\(name): expected an error", file: file, line: line)
        } catch {
            let error = error as NSError
            print("LIVE \(name) -> domain=\(error.domain) code=\(error.code) mm_code=\(error.mm_code ?? "nil") mm_message=\(error.mm_message ?? "nil") mm_httpStatusCode=\(error.mm_httpStatusCode.map(String.init) ?? "nil") localizedDescription=\"\(error.localizedDescription)\"")
            if let code = code {
                XCTAssertEqual(error.mm_code, code, name, file: file, line: line)
            }
            if let status = status {
                XCTAssertEqual(error.mm_httpStatusCode, status, name, file: file, line: line)
            }
            if local {
                XCTAssertEqual(error.domain, MMInternalErrorDomain, name, file: file, line: line)
                XCTAssertNil(error.mm_httpStatusCode, name, file: file, line: line)
            }
        }
    }

    private static func unsignedJwt(sub: String) -> String {
        let header = JWTSigner.base64URL(Data(#"{"alg":"HS256","typ":"JWT","kid":"k1"}"#.utf8))
        let claims = JWTSigner.base64URL(Data(#"{"sub":"\#(sub)","typ":"Bearer","iat":1700000000,"exp":4102444800,"jti":"1","infobip-api-key":"x"}"#.utf8))
        return "\(header).\(claims).c2lnbmF0dXJl"
    }
}
