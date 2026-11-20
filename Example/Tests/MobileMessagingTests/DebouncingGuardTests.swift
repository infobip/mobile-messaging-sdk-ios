//
//  Example/Tests/MobileMessagingTests/DebouncingGuardTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

// MARK: - MMDebouncingGuard unit tests

class DebouncingGuardTests: XCTestCase {
    private var originalDate: MMDate!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        originalDate = MobileMessaging.date
        MobileMessaging.date = DateStub(nowStub: start)
    }

    override func tearDown() {
        MobileMessaging.date = originalDate
        super.tearDown()
    }

    private func at(_ offset: TimeInterval) {
        MobileMessaging.date = DateStub(nowStub: start.addingTimeInterval(offset))
    }

    func testFirstCallIsAllowed() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testSameDataWithinWindowIsDropped() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        at(0.5)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testSameDataAtSameInstantIsDropped() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
        XCTAssertFalse(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
    }

    func testDifferentDataWithinWindowIsAllowed() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        at(0.1)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 2]))
        // the snapshot is replaced by the latest allowed call
        at(0.2)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 2]))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testSameDataAfterWindowIsAllowed() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: nil))
        at(1.0)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: nil))
        at(1.5)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: nil))
        at(2.01)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: nil))
    }

    func testNilDataIsDebounced() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: nil))
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: nil))
    }

    func testNilAndEmptyDataAreDifferent() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: nil))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: [:]))
    }

    func testNestedDataIsComparedDeeply() {
        let guardian = MMDebouncingGuard()
        let data: [String: Any] = ["identity": ["externalUserId": "e1", "emails": ["a@b.c"]], "flag": true]
        let equal: [String: Any] = ["flag": true, "identity": ["emails": ["a@b.c"], "externalUserId": "e1"]]
        let different: [String: Any] = ["identity": ["externalUserId": "e1", "emails": ["x@b.c"]], "flag": true]
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: data))
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: equal))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: different))
    }

    func testOperationTypesAreIndependent() {
        let guardian = MMDebouncingGuard()
        let data: [String: Any] = ["a": 1]
        for type in MMDebouncingGuard.OperationType.allCases {
            let ticket = guardian.admit(type, data: data)
            XCTAssertNotNil(ticket, "\(type)")
            ticket.map { guardian.succeeded($0) }
        }
        for type in MMDebouncingGuard.OperationType.allCases {
            XCTAssertFalse(guardian.shouldAllow(type, data: data), "\(type)")
        }
    }

    /// Writes are only dropped after an identical write succeeded; reads also while the first is still running.
    func testWritesAreOnlyDroppedAfterSuccess() {
        let guardian = MMDebouncingGuard()
        for type in [MMDebouncingGuard.OperationType.saveUser, .personalize, .depersonalizeInstallation] {
            let first = guardian.admit(type, data: ["a": 1])!
            let second = guardian.admit(type, data: ["a": 1])                 // first still running
            XCTAssertNotNil(second, "\(type): duplicate while the first is running is sent")
            guardian.succeeded(first)                                          // stale: no effect
            XCTAssertNotNil(guardian.admit(type, data: ["a": 1]), "\(type): the stored call has not succeeded yet")
        }
        let saved = guardian.admit(.saveUser, data: ["b": 1])!
        guardian.succeeded(saved)
        XCTAssertNil(guardian.admit(.saveUser, data: ["b": 1]), "after a success it is a duplicate")

        XCTAssertNotNil(guardian.admit(.fetchUser, data: nil))
        XCTAssertNil(guardian.admit(.fetchUser, data: nil), "reads are dropped while the first is still running")
    }

    func testReleaseAllowsImmediateRepeat() {
        let guardian = MMDebouncingGuard()
        let ticket = guardian.admit(.fetchUser, data: ["a": 1])
        XCTAssertNotNil(ticket)
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
        guardian.release(ticket!)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        XCTAssertFalse(guardian.shouldAllow(.userSessionReport, data: ["a": 1]), "release must affect only the ticket's type")
    }

    func testDroppedCallGetsNoTicket() {
        let guardian = MMDebouncingGuard()
        XCTAssertNotNil(guardian.admit(.fetchUser, data: ["a": 1]))
        XCTAssertNil(guardian.admit(.fetchUser, data: ["a": 1]))
    }

    /// A allowed, identical B allowed after the window, then A fails:
    /// A's release must not clear B's snapshot while B is still in flight.
    func testStaleReleaseDoesNotClearNewerIdenticalCall() {
        let guardian = MMDebouncingGuard()
        let ticketA = guardian.admit(.fetchUser, data: ["a": 1])!
        at(1.5)
        let ticketB = guardian.admit(.fetchUser, data: ["a": 1])
        XCTAssertNotNil(ticketB)

        guardian.release(ticketA)

        at(1.6)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 1]), "B is still in flight; a third identical call is a duplicate")
    }

    /// Same, with different data: an older failing call must not clear the snapshot of a newer different one.
    func testStaleReleaseDoesNotClearNewerDifferentCall() {
        let guardian = MMDebouncingGuard()
        let ticketA = guardian.admit(.fetchUser, data: ["a": 1])!
        XCTAssertNotNil(guardian.admit(.fetchUser, data: ["a": 2]))

        guardian.release(ticketA)

        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 2]))
    }

    func testReleasingTwiceIsHarmless() {
        let guardian = MMDebouncingGuard()
        let ticketA = guardian.admit(.fetchUser, data: ["a": 1])!
        guardian.release(ticketA)
        let ticketB = guardian.admit(.fetchUser, data: ["a": 1])
        XCTAssertNotNil(ticketB)
        guardian.release(ticketA)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testResetAll() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
        guardian.resetAll()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
    }

    func testInvalidateClearsSnapshotsAndBumpsGeneration() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))

        guardian.invalidate([.fetchUser])

        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]), "identical call after the transition is not a duplicate")
        XCTAssertFalse(guardian.shouldAllow(.userSessionReport, data: ["a": 1]), "other types are untouched")

        guardian.invalidate()
        XCTAssertTrue(guardian.shouldAllow(.userSessionReport, data: ["a": 1]))
    }

    func testBooleanAndNumberAreDifferent() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["customAttributes": ["value": true]]))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["customAttributes": ["value": 1]]), "true and 1 are different JSON")
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["customAttributes": ["value": false]]))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["customAttributes": ["value": 0]]), "false and 0 are different JSON")
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["customAttributes": ["value": 0]]))
    }

    func testBooleanAndNumberAreDifferentInArraysToo() {
        XCTAssertNotEqual(MMDebouncingGuard.canonicalKey(["a": [true, 1]]), MMDebouncingGuard.canonicalKey(["a": [1, 1]]))
        XCTAssertNotEqual(MMDebouncingGuard.canonicalKey(["a": [["b": true]]]), MMDebouncingGuard.canonicalKey(["a": [["b": 1]]]))
    }

    func testCanonicalKeyIsOrderIndependentAndTypeSensitive() {
        XCTAssertEqual(MMDebouncingGuard.canonicalKey(["a": 1, "b": ["c": "x", "d": NSNull()]]),
                       MMDebouncingGuard.canonicalKey(["b": ["d": NSNull(), "c": "x"], "a": 1]))
        XCTAssertNotEqual(MMDebouncingGuard.canonicalKey(["a": "1"]), MMDebouncingGuard.canonicalKey(["a": 1]))
        XCTAssertNotEqual(MMDebouncingGuard.canonicalKey(["a": NSNull()]), MMDebouncingGuard.canonicalKey(["a": 0]))
        XCTAssertNil(MMDebouncingGuard.canonicalKey(nil))
    }

    /// Precomposed "é" and "e" + combining acute are canonically equivalent Strings but different bytes on the wire.
    func testUnicodeCanonicallyEquivalentButDifferentlyEncodedTextIsDifferent() {
        let precomposed = "\u{00E9}", decomposed = "e\u{0301}"
        XCTAssertEqual(precomposed, decomposed, "precondition: Swift String equality treats them as equal")
        XCTAssertNotEqual(MMDebouncingGuard.canonicalKey(["externalUserId": precomposed]),
                          MMDebouncingGuard.canonicalKey(["externalUserId": decomposed]))

        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["externalUserId": precomposed]))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["externalUserId": decomposed]), "a distinct UTF-8 identity is not a duplicate")
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["externalUserId": decomposed]))
    }

    func testUnserializableDataIsNeverADuplicate() {
        let guardian = MMDebouncingGuard()
        let data: [String: Any] = ["date": Date()]
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: data))
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: data))
    }

    /// The window runs from the successful completion, not from admission: a slow request still dedups after it.
    func testWindowRunsFromSuccessfulCompletion() {
        let guardian = MMDebouncingGuard()
        let ticket = guardian.admit(.fetchUser, data: ["a": 1])!
        at(5)                                              // request took 5 s
        guardian.succeeded(ticket)
        at(5.5)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 1]), "0.5 s after success is a duplicate")
        at(6.1)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]), "the window after success has passed")
    }

    func testSucceededWithStaleTicketDoesNotRestartTheWindow() {
        let guardian = MMDebouncingGuard()
        let old = guardian.admit(.fetchUser, data: ["a": 1])!
        at(2)
        XCTAssertNotNil(guardian.admit(.fetchUser, data: ["a": 2]))
        at(2.5)
        guardian.succeeded(old)                            // late success of the older call
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 2]), "newer snapshot is unchanged")
        at(3.1)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testClockGoingBackwardsIsNotDropped() {
        let guardian = MMDebouncingGuard()
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        at(-0.5)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testCustomWindow() {
        let guardian = MMDebouncingGuard(window: 5)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        at(4.9)
        XCTAssertFalse(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
        at(10)
        XCTAssertTrue(guardian.shouldAllow(.fetchUser, data: ["a": 1]))
    }

    func testConcurrentCallsAllowExactlyOne() {
        let guardian = MMDebouncingGuard()
        let lock = NSLock()
        var allowed = 0
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            if guardian.shouldAllow(.fetchUser, data: ["a": 1]) {
                lock.lock(); allowed += 1; lock.unlock()
            }
        }
        XCTAssertEqual(allowed, 1)
    }
}

// MARK: - Integration with SDK API calls

/// Answers "make another installation primary" asynchronously after `release` is signalled.
private class HeldPrimaryChangeApiStub: RemoteAPIProviderStub {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    override func patchOtherInstance(applicationCode: String, authPushRegistrationId: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (UpdateInstanceDataResult) -> Void) {
        DispatchQueue.global().async {
            self.started.signal()
            self.release.wait()
            queue.async { completion(UpdateInstanceDataResult.Success(EmptyResponse())) }
        }
    }
}

/// A subservice whose depersonalization cleanup is held until `release` is signalled.
private class HeldCleanupSubservice: MobileMessagingService {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    override func depersonalizeService(_ mmContext: MobileMessaging, userInitiated: Bool, completion: @escaping () -> Void) {
        entered.signal()
        DispatchQueue.global().async {
            self.release.wait()
            completion()
        }
    }
}

/// Counts the depersonalization cleanups of the subservices (forced personalize).
private class CountingCleanupSubservice: MobileMessagingService {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
    override func depersonalizeService(_ mmContext: MobileMessaging, userInitiated: Bool, completion: @escaping () -> Void) {
        lock.lock(); _count += 1; lock.unlock()
        completion()
    }
}

/// Holds the depersonalize response until `release` is signalled, then answers success asynchronously.
private class HeldDepersonalizeApiStub: RemoteAPIProviderStub {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    override func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, queue: DispatchQueue, completion: @escaping (DepersonalizeResult) -> Void) {
        DispatchQueue.global().async {
            self.started.signal()
            self.release.wait()
            queue.async { completion(DepersonalizeResult.Success(EmptyResponse())) }
        }
    }
}

/// Answers depersonalize asynchronously, like a real network call (the base stub answers on the caller's queue).
private class AsyncDepersonalizeApiStub: RemoteAPIProviderStub {
    override func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, queue: DispatchQueue, completion: @escaping (DepersonalizeResult) -> Void) {
        DispatchQueue.global().async {
            let result = self.depersonalizeClosure!(applicationCode, pushRegistrationId, pushRegistrationIdToDepersonalize)
            queue.async { completion(result) }
        }
    }
}

class DebouncedApiCallsTests: MMTestCase {

    private final class Counter {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    private let retryableError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)

    /// Simulates an identical call that was just let through and succeeded (writes are only dropped after a success).
    private func seedSuccessfulCall(_ type: MMDebouncingGuard.OperationType, data: [String: Any]?) {
        let ticket = mobileMessagingInstance.debouncingGuard.admit(type, data: data)
        XCTAssertNotNil(ticket)
        ticket.map { mobileMessagingInstance.debouncingGuard.succeeded($0) }
    }

    /// Runs `work` on the SDK queue and returns what it calls back with. Resumes on the main queue: XCTest silently
    /// drops every failure recorded after a continuation was resumed directly on an SDK operation thread.
    private func onSDKQueue<T>(_ work: @escaping (@escaping (T) -> Void) -> Void) async -> T {
        await withCheckedContinuation { c in
            mobileMessagingInstance.queue.async { work { value in DispatchQueue.main.async { c.resume(returning: value) } } }
        }
    }

    /// Foreground/startup-style sync of whatever is not synced yet.
    private func syncUser() async {
        await onSDKQueue { done in self.mobileMessagingInstance.userService.syncWithServer(userInitiated: false) { _ in done(()) } }
    }

    private func advanceClock(by seconds: TimeInterval) {
        MobileMessaging.date = DateStub(nowStub: MobileMessaging.date.now.addingTimeInterval(seconds))
    }

    private var identity: MMUserIdentity { MMUserIdentity(phones: nil, emails: ["darth@vader.com"], externalUserId: "externalUserId")! }

    // MARK: personalize

    private func personalizeStub(_ counter: Counter, failFirst: Bool = false) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { [retryableError] _, _, _, _, _, _ -> PersonalizeResult in
            counter.increment()
            if failFirst && counter.count == 1 {
                return PersonalizeResult.Failure(retryableError)
            }
            return PersonalizeResult.Success(MMUser.empty)
        }
        return stub
    }

    func testIdenticalPersonalizeWithinWindowIsSentOnce() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 1)
    }

    func testPersonalizeWithDifferentDataIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "otherExternalUserId")!, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "otherExternalUserId")!, userAttributes: MMUserAttributes(firstName: "Darth", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil))

        XCTAssertEqual(counter.count, 3)
    }

    func testPersonalizeWithDifferentFlagsIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: true, userIdentity: identity, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: true, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 3)
    }

    func testIdenticalPersonalizeAfterWindowIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        advanceClock(by: MMDebouncingGuard.defaultWindow + 0.1)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 2)
    }

    func testIdenticalPersonalizeIsRetriedAfterFailure() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter, failFirst: true)

        do {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
            XCTFail("first personalize should fail")
        } catch {}
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 2)
    }

    func testDroppedPersonalizeDoesNotTouchDirtyUser() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)
        let key: [String: Any] = [
            "payload": UserDataMapper.personalizeRequestPayload(userIdentity: identity, userAttributes: nil) ?? [:],
            "forceDepersonalize": false,
            "keepAsLead": false,
            "setDeviceAsPrimary": false,
            "registration": MMTestConstants.kTestCorrectInternalID
        ]
        // simulate an identical call that was just let through
        seedSuccessfulCall(.personalize, data: key)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 0)
        XCTAssertNil(MobileMessaging.getUser()?.externalUserId)
    }

    // MARK: saveUser

    func testIdenticalSaveUserWithinWindowIsDroppedWithoutTouchingLocalData() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        // simulate an identical save that was just let through
        seedSuccessfulCall(.saveUser, data: saveDebounceKey(for: user))

        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 0)
        XCTAssertNil(MobileMessaging.getUser()?.firstName, "dropped save must not archive dirty data")
    }

    /// The PATCH body UpdateUserOperation will send for `user`; this is the save debounce key.
    private func patchBody(for user: MMUser) -> RequestBody? {
        UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: user)
    }

    /// The save debounce key: the PATCH body plus the registration it is sent for.
    private func saveDebounceKey(for user: MMUser) -> [String: Any] {
        ["payload": patchBody(for: user) ?? [:], "registration": MMTestConstants.kTestCorrectInternalID]
    }

    func testSaveUserWithSamePatchBodyButDifferentInstallationsAndTypeIsDropped() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let first = MobileMessaging.getUser()!
        first.firstName = "Darth"
        seedSuccessfulCall(.saveUser, data: saveDebounceKey(for: first))

        // same PATCH body, but fields the request never carries differ (e.g. refreshed by a background fetch)
        let otherInstallation = MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "other", deviceSecure: false, deviceTimeZone: nil, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.0", pushRegistrationId: "other-reg", pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
        let second = MMUser(externalUserId: nil, type: .Customer, firstName: "Darth", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: [otherInstallation])
        XCTAssertNotEqual(first.dictionaryRepresentation as NSDictionary, second.dictionaryRepresentation as NSDictionary)
        XCTAssertEqual(patchBody(for: first).map { $0 as NSDictionary }, patchBody(for: second).map { $0 as NSDictionary })

        try await MobileMessaging.saveUser(second)

        XCTAssertEqual(counter.count, 0)
    }

    func testSaveUserWithNothingToSendDoesNotConsumeDebounceWindow() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        // unchanged user: no delta, nothing sent, guard not consulted
        try await MobileMessaging.saveUser(MobileMessaging.getUser()!)
        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 1)
    }

    func testIdenticalSaveUserAfterWindowIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        seedSuccessfulCall(.saveUser, data: saveDebounceKey(for: user))
        advanceClock(by: MMDebouncingGuard.defaultWindow + 0.1)

        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Darth")
    }

    func testSaveUserWithDifferentDataIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "A"
        try await MobileMessaging.saveUser(user)
        user.firstName = "B"
        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "B")
    }

    func testIdenticalSaveUserIsRetriedAfterFailure() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { [retryableError] _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return counter.count == 1 ? UpdateUserDataResult.Failure(retryableError) : UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        do {
            try await MobileMessaging.saveUser(user)
            XCTFail("first save should fail")
        } catch {}
        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 2)
    }

    // MARK: a queued save sends only the fields it changed

    private func user(_ externalUserId: String?, _ firstName: String?, _ lastName: String?, customAttributes: [String: MMAttributeType]? = nil) -> MMUser {
        MMUser(externalUserId: externalUserId, type: .Customer, firstName: firstName, middleName: nil, lastName: lastName, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: customAttributes, installations: nil)
    }

    /// A save is queued, then a personalize (higher priority) overtakes it and replaces the user. The save must
    /// send only the field it changed, not the rest of its outdated snapshot (the previous identity).
    func testSaveOvertakenByPersonalizeSendsOnlyItsOwnFields() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        user("old-user", "Old", "Kept").archiveAll()
        let lock = NSLock()
        var order: [String] = [], patchBodies: [RequestBody] = []
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            lock.lock(); order.append("patch"); patchBodies.append(body); lock.unlock()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            lock.lock(); order.append("personalize"); lock.unlock()
            return PersonalizeResult.Success(self.user("new-user", "New", "Fresh"))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        installationQueue.isSuspended = true
        let save = Task { try await self.saveFirstName("Edited") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let personalize = Task {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "new-user")!, userAttributes: nil)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        try await personalize.value
        try await save.value

        XCTAssertEqual(order, ["personalize", "patch"], "precondition: the personalize overtook the save")
        XCTAssertEqual(patchBodies.count, 1)
        XCTAssertEqual(Set(patchBodies.first.map { Array($0.keys) } ?? []), ["firstName"], "only the field the save changed is sent")
        XCTAssertEqual(patchBodies.first?["firstName"] as? String, "Edited")

        let confirmed = mobileMessagingInstance.currentUser()
        XCTAssertEqual(confirmed.externalUserId, "new-user", "server-confirmed user keeps the personalized identity")
        XCTAssertEqual(confirmed.firstName, "Edited", "server-confirmed user has the saved field")
        XCTAssertEqual(confirmed.lastName, "Fresh", "server-confirmed user keeps the field the save did not change")
        // The local user is left alone: the personalize was called after the save, so its values are the latest
        // local state, and the next sync sends them (call order wins).
        let local = MobileMessaging.getUser()!
        XCTAssertEqual(local.externalUserId, "new-user")
        XCTAssertEqual(local.firstName, "New", "local user keeps the later personalize's value")
        XCTAssertEqual(local.lastName, "Fresh")

        await syncUser()
        XCTAssertEqual(patchBodies.count, 2)
        XCTAssertEqual(Set(patchBodies.last.map { Array($0.keys) } ?? []), ["firstName"], "the sync sends only what differs")
        XCTAssertEqual(patchBodies.last?["firstName"] as? String, "New", "the later personalize's value wins")
    }

    /// Same with custom attributes: the personalize changed one, the save another. Only the save's one is sent.
    func testSaveSendsOnlyTheCustomAttributesItChanged() {
        let confirmed = user("u", nil, nil, customAttributes: ["a": NSNumber(value: 1), "b": NSNumber(value: 2)])
        let saved = user("u", nil, nil, customAttributes: ["a": NSNumber(value: 1), "b": NSNumber(value: 3)])
        let fields = UserDataMapper.changedFields(of: saved, currentUser: confirmed, previousUser: confirmed)

        // meanwhile a personalize set a = 5 on the server
        let personalized = user("u", nil, nil, customAttributes: ["a": NSNumber(value: 5), "b": NSNumber(value: 2)])
        let body = UserDataMapper.restrict(UserDataMapper.requestPayload(currentUser: personalized, dirtyUser: saved) ?? [:], to: fields)

        XCTAssertEqual(Set(body.keys), ["customAttributes"])
        let attributes = body["customAttributes"] as? [String: Any]
        XCTAssertEqual(Set(attributes.map { Array($0.keys) } ?? []), ["b"], "the attribute the personalize changed is not sent back")
        XCTAssertEqual(attributes?["b"] as? NSNumber, 3)
    }

    /// A revert of a pending change equals the server-confirmed user, but is a changed field all the same.
    func testChangedFieldsOfARevertIncludeTheRevertedField() {
        let confirmed = user("u", "X", "L"), pending = user("u", "B", "L"), reverted = user("u", "X", "L")
        let fields = UserDataMapper.changedFields(of: reverted, currentUser: confirmed, previousUser: pending)
        XCTAssertEqual(Set(fields.keys), ["firstName"])
    }

    // MARK: persistUser

    /// personalize(A) -> persistUser(B) -> personalize(A): the local change ends the debounce, so the second
    /// personalize is sent and restores A (instead of being dropped and B being sent by the next sync).
    func testPersonalizeAfterPersistUserOfDifferentValueIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), patches = Counter()
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            personalizes.increment()
            return PersonalizeResult.Success(self.user("externalUserId", "A", nil))
        }
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            patches.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub
        let attributesA = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)
        let local = MobileMessaging.getUser()!
        local.firstName = "B"
        MobileMessaging.persistUser(local)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)

        XCTAssertEqual(personalizes.count, 2, "the local change in between makes the second personalize necessary")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A")
        await syncUser()
        XCTAssertEqual(patches.count, 0, "nothing left to sync: B was replaced by A")
    }

    // MARK: fetchUser

    private func fetchStub(_ counter: Counter, failFirst: Bool = false) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.getUserClosure = { [retryableError] _, _ -> FetchUserDataResult in
            counter.increment()
            if failFirst && counter.count == 1 {
                return FetchUserDataResult.Failure(retryableError)
            }
            return FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Darth", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        return stub
    }

    func testFetchUserWithinWindowIsSentOnceAndReturnsCachedUser() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = fetchStub(counter)

        let fetched1 = try await MobileMessaging.fetchUser()
        let fetched2 = try await MobileMessaging.fetchUser()

        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(fetched1.firstName, "Darth")
        XCTAssertEqual(fetched2.firstName, "Darth")
    }

    func testFetchUserAfterWindowIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = fetchStub(counter)

        _ = try await MobileMessaging.fetchUser()
        advanceClock(by: MMDebouncingGuard.defaultWindow + 0.1)
        _ = try await MobileMessaging.fetchUser()

        XCTAssertEqual(counter.count, 2)
    }

    func testFetchUserIsRetriedAfterFailure() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = fetchStub(counter, failFirst: true)

        do {
            _ = try await MobileMessaging.fetchUser()
            XCTFail("first fetch should fail")
        } catch {}
        _ = try await MobileMessaging.fetchUser()

        XCTAssertEqual(counter.count, 2)
    }

    /// Holds the first getUser request until `release` is signalled, then answers with `firstResult`.
    private func blockingFetchStub(_ counter: Counter, started: DispatchSemaphore, release: DispatchSemaphore, firstResult: @escaping () -> FetchUserDataResult) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            counter.increment()
            if counter.count == 1 {
                started.signal()
                release.wait()
                return firstResult()
            }
            return FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Second", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        return stub
    }

    private func fetchUser() async -> (user: MMUser?, error: NSError?) {
        await withCheckedContinuation { continuation in
            MobileMessaging.fetchUser { user, error in continuation.resume(returning: (user, error)) }
        }
    }

    private func mutateUserLocally(_ firstName: String) async {
        await withCheckedContinuation { c in
            mobileMessagingInstance.queue.async {
                let user = MobileMessaging.getUser()!
                user.firstName = firstName
                user.archiveDirty()
                c.resume()
            }
        }
    }

    func testFetchAfterDiscardedFetchResponseIsSent() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = blockingFetchStub(counter, started: started, release: release) {
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Fresh", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }

        let first = Task { await self.fetchUser() }
        await Task.detached { started.wait() }.value
        await mutateUserLocally("Local")                          // response of the first fetch will be discarded
        release.signal()
        _ = await first.value
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Local", "precondition: first response was discarded")

        _ = await fetchUser()                                     // immediately, within the window

        XCTAssertEqual(counter.count, 2, "a discarded response is not a successful refresh, so the next fetch must go out")
    }

    func testFetchRightAfterSlowSuccessfulFetchIsADuplicate() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = blockingFetchStub(counter, started: started, release: release) {
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Fresh", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }

        let first = Task { await self.fetchUser() }
        await Task.detached { started.wait() }.value
        advanceClock(by: MMDebouncingGuard.defaultWindow * 3)   // request takes longer than the window
        release.signal()
        _ = await first.value

        advanceClock(by: MMDebouncingGuard.defaultWindow / 2)
        let r2 = await fetchUser()

        XCTAssertEqual(counter.count, 1, "within the window after the successful completion")
        XCTAssertEqual(r2.user?.firstName, "Fresh")
    }

    // MARK: fetch responses vs local changes

    /// Answers getUser with "First", "Second", ... in request order.
    private func numberedFetchStub(_ counter: Counter) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            counter.increment()
            let name = ["First", "Second", "Third"][min(counter.count, 3) - 1]
            return FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: name, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        return stub
    }

    private func fetchUser(userInitiated: Bool) async -> (user: MMUser, error: NSError?) {
        await onSDKQueue { done in self.mobileMessagingInstance.userService.fetchFromServer(userInitiated: userInitiated) { done(($0, $1)) } }
    }

    /// A background and a user fetch (different keys) queued together: applying the first response is no local
    /// change, so the second fetch applies its own (newer) response instead of discarding it.
    func testFetchQueuedBehindAnotherFetchAppliesItsOwnResponse() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = numberedFetchStub(counter)

        installationQueue.isSuspended = true
        let background = Task { await self.fetchUser(userInitiated: false) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let user = Task { await self.fetchUser(userInitiated: true) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        _ = await background.value
        let second = await user.value

        XCTAssertEqual(counter.count, 2, "both fetches were sent")
        XCTAssertNil(second.error)
        XCTAssertEqual(second.user.firstName, "Second", "the second fetch reports its own response")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Second", "the newer response is applied")
    }

    /// A slow fetch outlives the window, so an identical fetch is admitted and queued behind it: it must apply
    /// its own response, not discard it because the first one was applied meanwhile.
    func testIdenticalFetchAdmittedAfterWindowBehindSlowFetchAppliesItsOwnResponse() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = blockingFetchStub(counter, started: started, release: release) {
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "First", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }

        let first = Task { await self.fetchUser() }
        await Task.detached { started.wait() }.value
        advanceClock(by: MMDebouncingGuard.defaultWindow * 2)   // the window expired while the first is in flight
        let second = Task { await self.fetchUser() }
        try? await Task.sleep(nanoseconds: 200_000_000)        // queued behind the first
        release.signal()
        _ = await first.value
        let r2 = await second.value

        XCTAssertEqual(counter.count, 2)
        XCTAssertNil(r2.error)
        XCTAssertEqual(r2.user?.firstName, "Second", "the second fetch reports its own response")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Second", "the newer response is applied")
    }

    /// A save made while a fetch is queued (its PATCH queued behind the fetch): the fetch response must not
    /// overwrite the unsynced local change, otherwise the local user ends with the server's old value.
    func testFetchQueuedBeforeSaveDoesNotOverwriteTheSave() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let fetches = Counter(), patches = Counter()
        let stub = RemoteAPIProviderStub()
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            fetches.increment()
            return FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Server", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            patches.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        installationQueue.isSuspended = true
        let fetch = Task { await self.fetchUser() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let save = Task { try await self.saveFirstName("Local") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        let fetched = await fetch.value
        try await save.value

        XCTAssertEqual(fetches.count, 1)
        XCTAssertEqual(patches.count, 1)
        XCTAssertNil(fetched.error)
        XCTAssertEqual(fetched.user?.firstName, "Local", "the fetch reports local data, its response was discarded")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Local", "the save is not overwritten by the fetch response")
        XCTAssertEqual(mobileMessagingInstance.currentUser().firstName, "Local")

        await syncUser()
        XCTAssertEqual(patches.count, 1, "nothing left to sync: local and server-confirmed user agree")
    }

    /// The server rejected a save, so the local user keeps the unsent value and no write is pending anymore: a
    /// fetch must still apply the server data (as before), not silently return the local data from then on.
    func testFetchAppliesServerDataAfterSaveWasRejected() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            UpdateUserDataResult.Failure(NSError(domain: "test", code: 400, userInfo: [NSLocalizedDescriptionKey: "rejected"]))
        }
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Server", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        do {
            try await saveFirstName("Rejected")
            XCTFail("the save should be rejected")
        } catch {}
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Rejected", "precondition: the local user keeps the rejected value")

        let fetched = await fetchUser()

        XCTAssertNil(fetched.error)
        XCTAssertEqual(fetched.user?.firstName, "Server", "the fetch reports the server data")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Server", "the server data is applied")
    }

    func testPersonalizeRightAfterSlowSuccessfulPersonalizeIsADuplicate() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            counter.increment()
            if counter.count == 1 { started.signal(); release.wait() }
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let first = Task { await self.personalize() }
        await Task.detached { started.wait() }.value
        advanceClock(by: MMDebouncingGuard.defaultWindow * 3)
        release.signal()
        _ = await first.value

        advanceClock(by: MMDebouncingGuard.defaultWindow / 2)
        _ = await personalize()
        XCTAssertEqual(counter.count, 1)

        advanceClock(by: MMDebouncingGuard.defaultWindow)
        _ = await personalize()
        XCTAssertEqual(counter.count, 2, "after the window following success, it is sent again")
    }

    // MARK: depersonalizeInstallation

    private func prepareInstallations() {
        mobileMessagingInstance.pushRegistrationId = "pr-0"
        let currentUser = MobileMessaging.getUser()!
        currentUser.installations = ["pr-0", "pr-1", "pr-2"].map {
            MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: $0, deviceSecure: false, deviceTimeZone: nil, isPrimaryDevice: $0 == "pr-0", isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.2", pushRegistrationId: $0, pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
        }
        currentUser.archiveAll()
    }

    private func depersonalizeInstallation(_ pushRegId: String) async -> (installations: [MMInstallation]?, error: NSError?) {
        await withCheckedContinuation { continuation in
            MobileMessaging.depersonalizeInstallation(withPushRegistrationId: pushRegId) { installations, error in
                continuation.resume(returning: (installations, error))
            }
        }
    }

    func testIdenticalDepersonalizeInstallationWithinWindowIsSentOnce() async {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            counter.increment()
            return DepersonalizeResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let r1 = await depersonalizeInstallation("pr-1")
        let r2 = await depersonalizeInstallation("pr-1")

        XCTAssertEqual(counter.count, 1)
        XCTAssertNil(r1.error)
        XCTAssertNil(r2.error)
        XCTAssertEqual(r2.installations?.count, 2)
        XCTAssertNil(r2.installations?.first(where: { $0.pushRegistrationId == "pr-1" }))
    }

    func testDepersonalizeDifferentInstallationIsSent() async {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            counter.increment()
            return DepersonalizeResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        _ = await depersonalizeInstallation("pr-1")
        let r = await depersonalizeInstallation("pr-2")

        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(r.installations?.count, 1)
    }

    func testIdenticalDepersonalizeInstallationIsRetriedAfterFailure() async {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { [retryableError] _, _, _ -> DepersonalizeResult in
            counter.increment()
            return counter.count == 1 ? DepersonalizeResult.Failure(retryableError) : DepersonalizeResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let r1 = await depersonalizeInstallation("pr-1")
        let r2 = await depersonalizeInstallation("pr-1")

        XCTAssertNotNil(r1.error)
        XCTAssertNil(r2.error)
        XCTAssertEqual(counter.count, 2)
    }

    // MARK: duplicates of a call still in flight get that call's real result

    private func personalize() async -> NSError? {
        await withCheckedContinuation { continuation in
            MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil) { continuation.resume(returning: $0) }
        }
    }

    // MARK: ordering of "last write wins" mutations (A → B → A)

    func testSaveUserABAWhileFirstInFlightSendsAlastAndEndsWithA() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let lock = NSLock()
        var sentFirstNames = [String]()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            counter.increment()
            lock.lock(); sentFirstNames.append(body["firstName"] as? String ?? "-"); lock.unlock()
            if counter.count == 1 { started.signal(); release.wait() }
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let save: (String) async -> NSError? = { name in
            let user = MobileMessaging.getUser()!
            user.firstName = name
            return await withCheckedContinuation { c in MobileMessaging.saveUser(user) { c.resume(returning: $0) } }
        }
        let a1 = Task { await save("A") }
        await Task.detached { started.wait() }.value
        let b = Task { await save("B") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let a2 = Task { await save("A") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        _ = await a1.value; _ = await b.value
        let lastError = await a2.value

        XCTAssertNil(lastError)
        XCTAssertEqual(sentFirstNames, ["A", "B", "A"], "the last A must be sent after B")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A", "final state must be what the last caller asked for")
    }

    func testPersonalizeABAWhileFirstInFlightSendsAlast() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let lock = NSLock()
        var sentExternalIds = [String]()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            counter.increment()
            let identity = body["userIdentity"] as? [String: Any]
            lock.lock(); sentExternalIds.append(identity?["externalUserId"] as? String ?? "-"); lock.unlock()
            if counter.count == 1 { started.signal(); release.wait() }
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let personalize: (String) async -> NSError? = { externalId in
            await withCheckedContinuation { c in
                MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: externalId)!, userAttributes: nil) { c.resume(returning: $0) }
            }
        }
        let a1 = Task { await personalize("A") }
        await Task.detached { started.wait() }.value
        let b = Task { await personalize("B") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let a2 = Task { await personalize("A") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        _ = await a1.value; _ = await b.value
        let lastError = await a2.value

        XCTAssertNil(lastError)
        XCTAssertEqual(sentExternalIds, ["A", "B", "A"], "the last personalize(A) must be sent after B")
    }

    func testPersonalizeChangingAttributeFromBooleanToNumberIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let lock = NSLock()
        var sentValues = [String]()
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            counter.increment()
            let value = ((body["userAttributes"] as? [String: Any])?["customAttributes"] as? [String: Any])?["value"]
            lock.lock(); sentValues.append(MMDebouncingGuard.canonicalKey(["v": value ?? NSNull()]).map { String(decoding: $0, as: UTF8.self) } ?? "-"); lock.unlock()
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let attributes: (MMAttributeType) -> MMUserAttributes = { value in
            MMUserAttributes(firstName: nil, middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: ["value": value])
        }
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributes(true as NSNumber))
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributes(1 as NSNumber))

        XCTAssertEqual(counter.count, 2, "changing true to 1 is a different request")
        XCTAssertEqual(sentValues, [#"{"v":true}"#, #"{"v":1}"#])
    }

    func testPersonalizeWithDifferentlyEncodedButEquivalentExternalUserIdIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let lock = NSLock()
        var sentIds = [[UInt8]]()
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            counter.increment()
            let id = (body["userIdentity"] as? [String: Any])?["externalUserId"] as? String ?? ""
            lock.lock(); sentIds.append(Array(id.utf8)); lock.unlock()
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        for id in ["\u{00E9}", "e\u{0301}"] {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: id)!, userAttributes: nil)
        }

        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(sentIds, [Array("\u{00E9}".utf8), Array("e\u{0301}".utf8)])
    }

    // MARK: changes made by other APIs break equivalence (no lost updates)

    private func serverEchoStub(_ personalizeCounter: Counter, _ saveCounter: Counter, fetchedFirstName: String = "B") -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            personalizeCounter.increment()
            let attributes = body["userAttributes"] as? [String: Any]
            return PersonalizeResult.Success(MMUser(externalUserId: "externalUserId", type: .Customer, firstName: attributes?["firstName"] as? String, middleName: nil, lastName: nil, phones: nil, emails: ["darth@vader.com"], tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saveCounter.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: fetchedFirstName, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        return stub
    }

    private func saveFirstName(_ name: String) async throws {
        let user = MobileMessaging.getUser()!
        user.firstName = name
        try await MobileMessaging.saveUser(user)
    }

    /// personalize(A) -> saveUser(B) -> personalize(A) within the window must end with A.
    func testPersonalizeAfterIntermediateSaveOfDifferentValueIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), saves = Counter()
        mobileMessagingInstance.remoteApiProvider = serverEchoStub(personalizes, saves)
        let attributesA = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)
        try await saveFirstName("B")
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)

        XCTAssertEqual(personalizes.count, 2, "the second personalize(A) must not be dropped")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A")
    }

    /// saveUser(A) -> fetchUser applies B -> saveUser(A) within the window must end with A.
    func testSaveAfterFetchAppliedDifferentValueIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), saves = Counter()
        mobileMessagingInstance.remoteApiProvider = serverEchoStub(personalizes, saves, fetchedFirstName: "B")

        try await saveFirstName("A")
        _ = try await MobileMessaging.fetchUser()
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "B", "precondition: fetch applied the server value")
        try await saveFirstName("A")

        XCTAssertEqual(saves.count, 2, "the second save(A) must not be dropped")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A")
    }

    /// personalize(A) done, saveUser(B) still being sent, personalize(A): A must be sent after B.
    func testPersonalizeWhileIntermediateSaveIsStillBeingSentIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), saves = Counter()
        let stub = serverEchoStub(personalizes, saves)
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saves.increment()
            started.signal()
            release.wait()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub
        let attributesA = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)
        let save = Task { try await self.saveFirstName("B") }
        await Task.detached { started.wait() }.value
        let secondPersonalize = Task {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: attributesA)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        try await save.value
        try await secondPersonalize.value

        XCTAssertEqual(personalizes.count, 2)
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A")
    }

    /// Server/cached value A, save B still pending, save A (no delta against the cached A at that moment):
    /// the revert must still reach the server after B.
    func testRevertToCachedValueWhileSaveIsPendingIsSentAfterIt() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let cached = MobileMessaging.getUser()!
        cached.firstName = "A"
        cached.archiveAll()                                       // the server has A
        let lock = NSLock()
        var sent = [String]()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            lock.lock(); sent.append(body["firstName"] as? String ?? "-"); let isFirst = sent.count == 1; lock.unlock()
            if isFirst { started.signal(); release.wait() }
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let saveB = Task { try await self.saveFirstName("B") }
        await Task.detached { started.wait() }.value
        let saveA = Task { try await self.saveFirstName("A") }    // back to the cached value while B is pending
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        try await saveB.value
        try await saveA.value

        XCTAssertEqual(sent, ["B", "A"], "the revert must be sent after B")
        XCTAssertEqual(mobileMessagingInstance.currentUser().firstName, "A", "server state ends with the last request")
    }

    /// Unchanged user and nothing pending: still completes right away without a request or an error.
    func testSaveWithoutChangesAndNothingPendingCompletesWithoutRequest() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let saves = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saves.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        try await MobileMessaging.saveUser(MobileMessaging.getUser()!)
        XCTAssertEqual(saves.count, 0)
    }

    /// A -> save B (pending) -> revert to A (no delta yet, queued) -> save B again: the last B must be sent.
    func testSaveAfterQueuedRevertIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let cached = MobileMessaging.getUser()!
        cached.firstName = "A"
        cached.archiveAll()
        let lock = NSLock()
        var sent = [String]()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            lock.lock(); sent.append(body["firstName"] as? String ?? "-"); let isFirst = sent.count == 1; lock.unlock()
            if isFirst { started.signal(); release.wait() }
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let saveB = Task { try await self.saveFirstName("B") }
        await Task.detached { started.wait() }.value
        let revert = Task { try await self.saveFirstName("A") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        try await saveB.value
        try await revert.value
        try await saveFirstName("B")

        XCTAssertEqual(sent, ["B", "A", "B"])
        XCTAssertEqual(mobileMessagingInstance.currentUser().firstName, "B")
    }

    /// saveUser(A) -> persistUser(B) -> foreground sync (sends B) -> saveUser(A): the last A must be sent.
    func testSaveAfterForegroundSyncOfOtherLocalChangeIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var sent = [String]()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            lock.lock(); sent.append(body["firstName"] as? String ?? "-"); lock.unlock()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        try await saveFirstName("A")
        let local = MobileMessaging.getUser()!
        local.firstName = "B"
        MobileMessaging.persistUser(local)                             // local only
        await onSDKQueue { done in self.mobileMessagingInstance.userService.appWillEnterForeground { done(()) } }
        try await saveFirstName("A")

        XCTAssertEqual(sent, ["A", "B", "A"])
        XCTAssertEqual(mobileMessagingInstance.currentUser().firstName, "A")
    }

    /// personalize(setDeviceAsPrimary) -> another installation made primary -> same personalize: must be sent.
    func testPersonalizeAsPrimaryAfterAnotherInstallationWasMadePrimaryIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let personalizes = Counter()
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            personalizes.increment()
            return PersonalizeResult.Success(MMUser.empty)
        }
        stub.patchOtherInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
            UpdateInstanceDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)
        _ = try await MobileMessaging.setInstallation(withPushRegistrationId: "pr-1", asPrimary: true)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(personalizes.count, 2, "this device must be made primary again")
    }

    /// save B queued, personalize A queued (runs first: higher priority) and succeeds, then save B applies:
    /// personalize A again must be sent.
    func testPersonalizeAfterEarlierQueuedSaveAppliedLaterIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), saves = Counter()
        let lock = NSLock()
        var order = [String]()
        let stub = serverEchoStub(personalizes, saves)
        let echoPersonalize = stub.personalizeClosure!
        stub.personalizeClosure = { a, b, body, c, d, e in
            lock.lock(); order.append("personalize"); lock.unlock()
            return echoPersonalize(a, b, body, c, d, e)
        }
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saves.increment()
            lock.lock(); order.append("save"); lock.unlock()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub
        let attributesA = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)

        installationQueue.isSuspended = true
        let save = Task { try await self.saveFirstName("B") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let first = Task {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: attributesA)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        try await first.value
        try await save.value
        XCTAssertEqual(order, ["personalize", "save"], "precondition: the personalize overtook the save")

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)

        XCTAssertEqual(personalizes.count, 2, "the save changed the server after the first personalize")
        XCTAssertEqual(order.last, "personalize")
    }

    /// another installation made primary (response held), personalize(setDeviceAsPrimary) succeeds, then the
    /// primary change completes: the same personalize must be sent again.
    func testPersonalizeAsPrimaryAfterLateCompletingPrimaryChangeIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let personalizes = Counter()
        let stub = HeldPrimaryChangeApiStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            personalizes.increment()
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let primaryChange = Task { try await MobileMessaging.setInstallation(withPushRegistrationId: "pr-1", asPrimary: true) }
        await Task.detached { stub.started.wait() }.value
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)
        stub.release.signal()
        _ = try await primaryChange.value

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(personalizes.count, 2, "the other installation became primary after the first personalize")
    }

    func testIdenticalSaveRightAfterSaveWithoutOtherChangesIsStillDropped() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let personalizes = Counter(), saves = Counter()
        mobileMessagingInstance.remoteApiProvider = serverEchoStub(personalizes, saves)
        let attributesA = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: attributesA)
        XCTAssertEqual(personalizes.count, 1)
    }

    // MARK: identity / registration transitions invalidate equivalence

    private func forcedPersonalize() async -> NSError? {
        await withCheckedContinuation { continuation in
            MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: identity, userAttributes: nil) { continuation.resume(returning: $0) }
        }
    }

    func testIdenticalForcedPersonalizeRightAfterSuccessfulOneIsADuplicate() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter)

        let e1 = await forcedPersonalize()
        let e2 = await forcedPersonalize()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 1, "its own depersonalization must not invalidate the forced personalize's entry")
        XCTAssertEqual(MobileMessaging.getUser()?.externalUserId, "externalUserId")
    }

    func testForcedPersonalizeStillInvalidatesOtherOperations() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let saves = Counter()
        let stub = personalizeAndDepersonalizeStub(Counter())
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saves.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        seedSuccessfulCall(.saveUser, data: saveDebounceKey(for: user))

        _ = await forcedPersonalize()

        let newUser = MobileMessaging.getUser()!
        newUser.firstName = "Darth"
        try await MobileMessaging.saveUser(newUser)
        XCTAssertEqual(saves.count, 1)
    }

    func testLogoutStillInvalidatesPersonalize() async {
        MMTestCase.startWithCorrectApplicationCode()
        seedSuccessfulCall(.personalize, data: ["a": 1])
        await withCheckedContinuation { c in
            mobileMessagingInstance.queue.async {
                DepersonalizeOperation.depersonalizeSubservices(userInitiated: true, mmContext: self.mobileMessagingInstance)
                c.resume()
            }
        }
        XCTAssertTrue(mobileMessagingInstance.debouncingGuard.shouldAllow(.personalize, data: ["a": 1]), "logout clears it")
    }

    private func personalizeAndDepersonalizeStub(_ personalizeCounter: Counter, personalizeStarted: DispatchSemaphore? = nil, releasePersonalize: DispatchSemaphore? = nil) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            personalizeCounter.increment()
            if personalizeCounter.count == 1, let started = personalizeStarted, let release = releasePersonalize {
                started.signal()
                release.wait()
            }
            return PersonalizeResult.Success(MMUser(externalUserId: "externalUserId", type: .Customer, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: ["darth@vader.com"], tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            DepersonalizeResult.Success(EmptyResponse())
        }
        return stub
    }

    func testPersonalizeLogoutPersonalizeSameUserWithinWindowIsSentAndRestoresIdentity() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        XCTAssertEqual(MobileMessaging.getUser()?.externalUserId, "externalUserId")
        try await MobileMessaging.depersonalize()
        XCTAssertNil(MobileMessaging.getUser()?.externalUserId)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 2, "personalize after logout must reach the server")
        XCTAssertEqual(MobileMessaging.getUser()?.externalUserId, "externalUserId", "local identity must be restored")
    }

    /// Answers personalize with the requested identity and records the external user IDs in request order.
    private func identityRecordingPersonalizeStub(_ lock: NSLock, _ order: @escaping (String) -> Void) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            let externalUserId = (body["userIdentity"] as? [String: Any])?["externalUserId"] as? String ?? "?"
            lock.lock(); order(externalUserId); lock.unlock()
            return PersonalizeResult.Success(MMUser(externalUserId: externalUserId, type: .Customer, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in DepersonalizeResult.Success(EmptyResponse()) }
        return stub
    }

    private func personalize(externalUserId: String) async throws {
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: externalUserId)!, userAttributes: nil)
    }

    /// personalize(A) succeeded, personalize(B) is still queued, personalize(A) again: the last A must not be
    /// dropped as a duplicate of the first, otherwise B runs last and the SDK ends personalized as B.
    func testPersonalizeAfterQueuedPersonalizeOfAnotherUserIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var order: [String] = []
        mobileMessagingInstance.remoteApiProvider = identityRecordingPersonalizeStub(lock) { order.append($0) }

        try await personalize(externalUserId: "A")
        installationQueue.isSuspended = true                       // a busy queue: B waits
        let b = Task { try await self.personalize(externalUserId: "B") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let a = Task { try await self.personalize(externalUserId: "A") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        try await b.value
        try await a.value

        XCTAssertEqual(order, ["A", "B", "A"])
        XCTAssertEqual(MobileMessaging.getUser()?.externalUserId, "A", "the last call wins")
    }

    /// A logout failed and is pending; a personalize succeeds meanwhile; the logout retry succeeds and depersonalizes
    /// the installation on the server. An identical personalize right after must be sent, not dropped with success.
    func testPersonalizeAfterPendingLogoutSucceededIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var order: [String] = []
        mobileMessagingInstance.remoteApiProvider = identityRecordingPersonalizeStub(lock) { order.append($0) }
        let internalData = mobileMessagingInstance.internalData()
        internalData.currentDepersonalizationStatus = .pending           // an earlier logout failed
        internalData.archiveCurrent()

        try await personalize(externalUserId: "A")
        let status = try await MobileMessaging.depersonalize()          // the retry succeeds
        XCTAssertEqual(mobileMessagingInstance.internalData().currentDepersonalizationStatus, .success, "precondition: the pending logout completed (got \(status.rawValue))")
        try await personalize(externalUserId: "A")

        XCTAssertEqual(order, ["A", "A"], "the logout in between makes the second personalize necessary")
    }

    // MARK: installation changes vs personalize and fetch

    private func installation(primary: Bool, attributes: [String: MMAttributeType] = [:]) -> MMInstallation {
        MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: attributes, deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "this", deviceSecure: false, deviceTimeZone: nil, isPrimaryDevice: primary, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.0", pushRegistrationId: MMTestConstants.kTestCorrectInternalID, pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
    }

    private func personalizeAsPrimary() async throws {
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, setDeviceAsPrimary: true, userIdentity: identity, userAttributes: nil)
    }

    /// personalize(setDeviceAsPrimary) -> saveInstallation(not primary) -> same personalize: sent again.
    func testPersonalizeAsPrimaryAfterSaveInstallationIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = personalizeStub(counter)
        stub.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in UpdateInstanceDataResult.Success(EmptyResponse()) }
        mobileMessagingInstance.remoteApiProvider = stub

        try await personalizeAsPrimary()
        let current = MobileMessaging.getInstallation()!
        current.isPrimaryDevice = false
        try await MobileMessaging.saveInstallation(current)
        try await personalizeAsPrimary()

        XCTAssertEqual(counter.count, 2, "the installation change makes setting this device as primary necessary again")
    }

    /// personalize(setDeviceAsPrimary) -> fetchInstallation applies "not primary" -> same personalize: sent again.
    func testPersonalizeAsPrimaryAfterAppliedInstallationFetchIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = personalizeStub(counter)
        stub.getInstanceClosure = { [unowned self] _, _ -> FetchInstanceDataResult in FetchInstanceDataResult.Success(self.installation(primary: false)) }
        mobileMessagingInstance.remoteApiProvider = stub

        try await personalizeAsPrimary()
        let fetchError: NSError? = await withCheckedContinuation { c in MobileMessaging.fetchInstallation { _, error in c.resume(returning: error) } }
        XCTAssertNil(fetchError)
        try await personalizeAsPrimary()

        XCTAssertEqual(counter.count, 2, "the fetched installation makes setting this device as primary necessary again")
    }

    /// fetchInstallations -> saveInstallation(new attributes) -> fetchInstallations: the second fetch is sent.
    func testFetchInstallationsAfterSaveInstallationIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let fetches = Counter()
        let stub = fetchStub(fetches)
        stub.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in UpdateInstanceDataResult.Success(EmptyResponse()) }
        mobileMessagingInstance.remoteApiProvider = stub

        _ = try await MobileMessaging.fetchInstallations()
        let current = MobileMessaging.getInstallation()!
        current.customAttributes = ["plan": "gold" as NSString]
        try await MobileMessaging.saveInstallation(current)
        _ = try await MobileMessaging.fetchInstallations()

        XCTAssertEqual(fetches.count, 2, "the installation change makes the cached installation list stale")
    }

    // MARK: personalize sends exactly what its key describes

    /// The caller mutates the attributes object after calling personalize, before the queued operation runs. The
    /// request must carry the values at call time (the ones the debounce key describes), not the mutated ones.
    func testPersonalizeSendsTheAttributesAsTheyWereWhenCalled() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var firstNames: [String] = []
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            let name = (body["userAttributes"] as? [String: Any])?["firstName"] as? String ?? "nil"
            lock.lock(); firstNames.append(name); lock.unlock()
            return PersonalizeResult.Success(MMUser(externalUserId: "externalUserId", type: .Customer, firstName: name, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let attributes = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)
        installationQueue.isSuspended = true
        let first = Task { try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: attributes) }
        try? await Task.sleep(nanoseconds: 200_000_000)               // accepted by the SDK, still queued
        attributes.firstName = "B"
        installationQueue.isSuspended = false
        try await first.value
        let fresh = MMUserAttributes(firstName: "A", middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: fresh)

        XCTAssertEqual(firstNames.first, "A", "the request carries the attributes as they were when personalize was called")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "A", "the user ends with A")
    }

    // MARK: confirming a save keeps a newer local change

    /// S1 (firstName First) is in flight; S2 reverts firstName to the confirmed value and changes lastName. S1
    /// succeeds, S2 fails: the local user must keep S2's values, the newer intent, not take S1's firstName.
    func testRejectedRevertKeepsTheLatestLocalUser() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        user("externalUserId", "Original", "Kept").archiveAll()
        let patches = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { [retryableError] _, _, _ -> UpdateUserDataResult in
            patches.increment()
            if patches.count == 1 { started.signal(); release.wait(); return UpdateUserDataResult.Success(EmptyResponse()) }
            return UpdateUserDataResult.Failure(retryableError)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let s1 = Task { try await self.saveFirstName("First") }
        await Task.detached { started.wait() }.value
        let revert = MobileMessaging.getUser()!
        revert.firstName = "Original"
        revert.lastName = "Changed"
        let s2 = Task { try await MobileMessaging.saveUser(revert) }
        try? await Task.sleep(nanoseconds: 200_000_000)               // S2 is queued behind S1
        release.signal()
        try await s1.value
        do { try await s2.value; XCTFail("S2 should fail") } catch {}

        XCTAssertEqual(patches.count, 2)
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Original", "the newer revert is kept locally")
        XCTAssertEqual(MobileMessaging.getUser()?.lastName, "Changed")
        let unsynced = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
        XCTAssertEqual(unsynced?["firstName"] as? String, "Original", "the revert is still waiting to be synced")
    }

    /// S1 (firstName First) is in flight; persistUser reverts firstName to the confirmed value locally. When S1
    /// succeeds, the local revert must survive and still be waiting to be synced.
    func testPersistedRevertSurvivesEarlierSaveSuccess() async throws {
        try await assertPersistedRevertSurvivesEarlierSave(
            saved: { $0.firstName = "First" },
            reverted: { $0.firstName = "Original" },
            local: { $0.firstName },
            unsyncedKey: "firstName")
    }

    /// A personalize P is in flight when save S1 (First) is queued; P's response is applied, S1 is sent, and
    /// persistUser reverts firstName to Original while S1 is in flight. When S1 succeeds the revert must survive.
    func testPersistedRevertAfterQueuedPersonalizeSurvivesSaveSuccess() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        user("externalUserId", "Original", nil).archiveAll()
        let personalizeStarted = DispatchSemaphore(value: 0), releasePersonalize = DispatchSemaphore(value: 0)
        let patchStarted = DispatchSemaphore(value: 0), releasePatch = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            personalizeStarted.signal(); releasePersonalize.wait()
            return PersonalizeResult.Success(self.user("externalUserId", "Original", nil))
        }
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            patchStarted.signal(); releasePatch.wait()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let p = Task { try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: nil) }
        await Task.detached { personalizeStarted.wait() }.value
        let s1 = Task { try await self.saveFirstName("First") }     // queued behind P
        try? await Task.sleep(nanoseconds: 200_000_000)
        releasePersonalize.signal()
        try await p.value
        await Task.detached { patchStarted.wait() }.value            // S1 in flight
        let revert = MobileMessaging.getUser()!
        revert.firstName = "Original"
        MobileMessaging.persistUser(revert)
        releasePatch.signal()
        try await s1.value

        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Original", "the newer local revert is kept")
        let unsynced = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
        XCTAssertEqual(unsynced?["firstName"] as? String, "Original", "the revert is still waiting to be synced")
    }

    /// Same with a custom attribute.
    func testPersistedCustomAttributeRevertSurvivesEarlierSaveSuccess() async throws {
        try await assertPersistedRevertSurvivesEarlierSave(
            saved: { $0.customAttributes = ["plan": "First" as NSString] },
            reverted: { $0.customAttributes = ["plan": "Original" as NSString] },
            local: { $0.customAttributes?["plan"] as? String },
            unsyncedKey: "customAttributes")
    }

    private func assertPersistedRevertSurvivesEarlierSave(saved: @escaping (MMUser) -> Void, reverted: @escaping (MMUser) -> Void, local: @escaping (MMUser) -> String?, unsyncedKey: String) async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let original = user("externalUserId", "Original", nil, customAttributes: ["plan": "Original" as NSString])
        original.archiveAll()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            started.signal(); release.wait()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let s1 = Task { () -> Void in
            let u = MobileMessaging.getUser()!
            saved(u)
            try await MobileMessaging.saveUser(u)
        }
        await Task.detached { started.wait() }.value
        let revert = MobileMessaging.getUser()!
        reverted(revert)
        MobileMessaging.persistUser(revert)
        release.signal()
        try await s1.value

        XCTAssertEqual(local(MobileMessaging.getUser()!), "Original", "the newer local revert is kept")
        let unsynced = UserDataMapper.requestPayload(currentUser: mobileMessagingInstance.currentUser(), dirtyUser: mobileMessagingInstance.dirtyUser())
        XCTAssertNotNil(unsynced?[unsyncedKey], "the revert is still waiting to be synced")
    }

    // MARK: mutable custom attribute values

    /// The caller passes an NSMutableString custom attribute and changes it after personalize was accepted. The
    /// request must carry the value at call time; a later identical personalize is then a real duplicate.
    func testPersonalizeSendsMutableCustomAttributeAsItWasWhenCalled() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var plans: [String] = []
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, body, _, _, _ -> PersonalizeResult in
            let plan = ((body["userAttributes"] as? [String: Any])?["customAttributes"] as? [String: Any])?["plan"] as? String ?? "nil"
            lock.lock(); plans.append(plan); lock.unlock()
            return PersonalizeResult.Success(MMUser(externalUserId: "externalUserId", type: .Customer, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: ["plan": plan as NSString], installations: nil))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let value = NSMutableString(string: "A")
        let attributes = MMUserAttributes(firstName: nil, middleName: nil, lastName: nil, tags: nil, gender: nil, birthday: nil, customAttributes: ["plan": value])
        installationQueue.isSuspended = true
        let first = Task { try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: attributes) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        value.setString("B")
        installationQueue.isSuspended = false
        try await first.value

        XCTAssertEqual(plans.first, "A", "the request carries the value at call time")
    }

    /// Same for saveUser: the PATCH carries the value at call time, which the debounce key describes.
    func testSaveSendsMutableCustomAttributeAsItWasWhenCalled() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var plans: [String] = []
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, body -> UpdateUserDataResult in
            let plan = (body["customAttributes"] as? [String: Any])?["plan"] as? String ?? "nil"
            lock.lock(); plans.append(plan); lock.unlock()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let value = NSMutableString(string: "A")
        let u = MobileMessaging.getUser()!
        u.customAttributes = ["plan": value]
        installationQueue.isSuspended = true
        let first = Task { try await MobileMessaging.saveUser(u) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        value.setString("B")
        installationQueue.isSuspended = false
        try await first.value

        XCTAssertEqual(plans, ["A"], "the PATCH carries the value at call time")
        XCTAssertEqual(MobileMessaging.getUser()?.customAttributes?["plan"] as? String, "A")
    }

    // MARK: logout (depersonalize of this installation)

    /// Counts depersonalize requests; the first one can be held until `release` and/or fail.
    private func logoutStub(_ counter: Counter, failFirst: Bool = false, started: DispatchSemaphore? = nil, release: DispatchSemaphore? = nil) -> RemoteAPIProviderStub {
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { [retryableError] _, _, _ -> DepersonalizeResult in
            counter.increment()
            if counter.count == 1 {
                if let started = started, let release = release { started.signal(); release.wait() }
                if failFirst { return DepersonalizeResult.Failure(retryableError) }
            }
            return DepersonalizeResult.Success(EmptyResponse())
        }
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in PersonalizeResult.Success(MMUser.empty) }
        return stub
    }

    private func logout() async -> NSError? {
        do {
            _ = try await MobileMessaging.depersonalize()
            return nil
        } catch {
            return error as NSError
        }
    }

    func testIdenticalLogoutRightAfterSuccessfulOneIsNotSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter)
        let cleanup = CountingCleanupSubservice(mmContext: mobileMessagingInstance, uniqueIdentifier: "CountingCleanupSubservice")
        mobileMessagingInstance.registerSubservice(cleanup)

        let e1 = await logout()
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 1, "the second logout is not sent")
        XCTAssertEqual(cleanup.count, 1, "the second logout does not clean up the subservices again")
    }

    func testLogoutWhileFirstIsInFlightIsSentOnce() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter, started: started, release: release)
        let cleanup = CountingCleanupSubservice(mmContext: mobileMessagingInstance, uniqueIdentifier: "CountingCleanupSubservice")
        mobileMessagingInstance.registerSubservice(cleanup)

        let first = Task { await self.logout() }
        await Task.detached { started.wait() }.value
        let second = Task { await self.logout() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        let e1 = await first.value, e2 = await second.value

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 1, "the duplicate waits for the first one and is not sent once it succeeded")
        XCTAssertEqual(cleanup.count, 1)
    }

    func testLogoutIsSentAgainAfterFailedOne() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter, failFirst: true)

        let e1 = await logout()
        let e2 = await logout()

        XCTAssertNotNil(e1, "the first logout reports its failure")
        XCTAssertNil(e2, "the retry is sent and succeeds")
        XCTAssertEqual(counter.count, 2, "a failed logout never blocks a retry")
        XCTAssertEqual(mobileMessagingInstance.internalData().currentDepersonalizationStatus, .success, "the pending logout completed")
    }

    func testLogoutAfterPersonalizeIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter)

        let e1 = await logout()
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the personalize in between makes the second logout necessary")
    }

    private func logoutAndInstallationStub(_ counter: Counter) -> RemoteAPIProviderStub {
        let stub = logoutStub(counter)
        stub.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in UpdateInstanceDataResult.Success(EmptyResponse()) }
        return stub
    }

    /// logout -> setInstallation(this device, asPrimary: true) -> logout: the second logout is sent and resets the flag.
    func testLogoutAfterMakingThisDevicePrimaryIsSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutAndInstallationStub(counter)

        let e1 = await logout()
        let primaryError: NSError? = await withCheckedContinuation { c in
            MobileMessaging.setInstallation(withPushRegistrationId: MMTestConstants.kTestCorrectInternalID, asPrimary: true) { _, error in c.resume(returning: error) }
        }
        XCTAssertNil(primaryError)
        XCTAssertEqual(MobileMessaging.getInstallation()?.isPrimaryDevice, true, "precondition: this device is primary")
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the primary change in between makes the second logout necessary")
        XCTAssertEqual(MobileMessaging.getInstallation()?.isPrimaryDevice, false, "the second logout reset the primary flag")
    }

    /// logout -> persistInstallation(new attributes) -> logout: the second logout is sent and clears the attributes.
    func testLogoutAfterPersistInstallationIsSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutAndInstallationStub(counter)

        let e1 = await logout()
        let installation = MobileMessaging.getInstallation()!
        installation.customAttributes = ["plan": "gold" as NSString]
        MobileMessaging.persistInstallation(installation)
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the local installation change makes the second logout necessary")
        XCTAssertEqual(MobileMessaging.getInstallation()?.customAttributes.isEmpty, true, "the second logout cleared the attributes")
    }

    /// logout -> saveInstallation(new attributes) -> logout: the second logout is sent and clears the attributes.
    func testLogoutAfterSaveInstallationIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutAndInstallationStub(counter)

        let e1 = await logout()
        let installation = MobileMessaging.getInstallation()!
        installation.customAttributes = ["plan": "gold" as NSString]
        try await MobileMessaging.saveInstallation(installation)
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the installation change makes the second logout necessary")
        XCTAssertEqual(MobileMessaging.getInstallation()?.customAttributes.isEmpty, true, "the second logout cleared the attributes")
    }

    /// Busy queue: logout L1 is queued, then saveInstallation S (normal priority). L1 runs first, S then sends its
    /// attributes. A logout L2 right after must be sent, otherwise the attributes stay although the app called
    /// L1, S, L2.
    func testLogoutAfterInstallationSaveOvertakenByEarlierLogoutIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var order: [String] = []
        let logouts = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            logouts.increment(); lock.lock(); order.append("logout"); lock.unlock()
            return DepersonalizeResult.Success(EmptyResponse())
        }
        stub.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
            lock.lock(); order.append("save"); lock.unlock()
            return UpdateInstanceDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        installationQueue.isSuspended = true                       // a busy queue
        let l1 = Task { await self.logout() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let installation = MobileMessaging.getInstallation()!
        installation.customAttributes = ["plan": "gold" as NSString]
        let s = Task { try await MobileMessaging.saveInstallation(installation) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        _ = await l1.value
        try await s.value
        XCTAssertEqual(order, ["logout", "save"], "precondition: the logout overtook the save")

        let e2 = await logout()

        XCTAssertNil(e2)
        XCTAssertEqual(logouts.count, 2, "the save that went out after the first logout makes the second one necessary")
    }

    /// Same with the automatic foreground sync of a locally persisted installation change: logout L1 overtakes the
    /// queued sync, the sync's PATCH restores the attributes, and a logout L2 right after must be sent.
    func testLogoutAfterForegroundInstallationSyncOvertakenByEarlierLogoutIsSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let lock = NSLock()
        var order: [String] = []
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            lock.lock(); order.append("logout"); lock.unlock()
            return DepersonalizeResult.Success(EmptyResponse())
        }
        stub.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
            lock.lock(); order.append("patch"); lock.unlock()
            return UpdateInstanceDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        installationQueue.isSuspended = true                       // a busy queue
        let l1 = Task { await self.logout() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let installation = MobileMessaging.getInstallation()!
        installation.customAttributes = ["plan": "gold" as NSString]
        MobileMessaging.persistInstallation(installation)
        let sync = Task { await self.onSDKQueue { done in self.mobileMessagingInstance.installationService.appWillEnterForeground { done(()) } } }
        try? await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.isSuspended = false
        _ = await l1.value
        await sync.value
        XCTAssertEqual(order, ["logout", "patch"], "precondition: the logout overtook the foreground sync")

        let e2 = await logout()

        XCTAssertNil(e2)
        XCTAssertEqual(order, ["logout", "patch", "logout"], "the sync that went out after the first logout makes the second one necessary")
        XCTAssertEqual(MobileMessaging.getInstallation()?.customAttributes.isEmpty, true, "the second logout cleared the attributes")
    }

    /// logout -> fetchInstallation (server returns attributes and primary=true) -> logout: the fetch changed what the
    /// logout reset, so the second logout is sent and resets it again.
    func testLogoutAfterAppliedInstallationFetchIsSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        let regId = MMTestConstants.kTestCorrectInternalID
        mobileMessagingInstance.pushRegistrationId = regId
        let counter = Counter()
        let stub = logoutStub(counter)
        stub.getInstanceClosure = { _, _ -> FetchInstanceDataResult in
            FetchInstanceDataResult.Success(MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: ["plan": "gold" as NSString], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: "this", deviceSecure: false, deviceTimeZone: nil, isPrimaryDevice: true, isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.0", pushRegistrationId: regId, pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let e1 = await logout()
        let fetchError: NSError? = await withCheckedContinuation { c in
            MobileMessaging.fetchInstallation { _, error in c.resume(returning: error) }
        }
        XCTAssertNil(fetchError)
        XCTAssertEqual(MobileMessaging.getInstallation()?.isPrimaryDevice, true, "precondition: the fetched installation was applied")
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the applied fetch makes the second logout necessary")
        XCTAssertEqual(MobileMessaging.getInstallation()?.isPrimaryDevice, false, "the second logout reset the primary flag")
        XCTAssertEqual(MobileMessaging.getInstallation()?.customAttributes.isEmpty, true, "the second logout cleared the attributes")
    }

    /// A pending logout (an earlier one failed) is always sent, even if the guard remembers a successful identical one.
    func testPendingLogoutIsSentEvenIfGuardRemembersASuccess() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter)
        let regId = MMTestConstants.kTestCorrectInternalID
        seedSuccessfulCall(.depersonalizeInstallation, data: ["pushRegId": regId, "registration": regId])
        let internalData = mobileMessagingInstance.internalData()
        internalData.currentDepersonalizationStatus = .pending
        internalData.archiveCurrent()

        let error = await logout()

        XCTAssertNil(error)
        XCTAssertEqual(counter.count, 1, "the pending logout is sent")
        XCTAssertEqual(mobileMessagingInstance.internalData().currentDepersonalizationStatus, .success)
    }

    /// logout -> saveUser(new identity) -> logout: the user data changed, so the second logout is sent and erases it.
    func testLogoutAfterSaveUserIsSentAgain() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = logoutStub(counter)
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in UpdateUserDataResult.Success(EmptyResponse()) }
        mobileMessagingInstance.remoteApiProvider = stub

        let e1 = await logout()
        let user = MobileMessaging.getUser()!
        user.externalUserId = "new-identity"
        try await MobileMessaging.saveUser(user)
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the save in between makes the second logout necessary")
        XCTAssertNil(MobileMessaging.getUser()?.externalUserId, "the second logout erased the new identity locally")
    }

    /// logout -> persistUser(new data) -> logout: the second logout is sent and erases the locally persisted data.
    func testLogoutAfterPersistUserIsSentAgain() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = logoutStub(counter)

        let e1 = await logout()
        let user = MobileMessaging.getUser()!
        user.firstName = "Persisted"
        MobileMessaging.persistUser(user)
        let e2 = await logout()

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 2, "the local change in between makes the second logout necessary")
        XCTAssertNil(MobileMessaging.getUser()?.firstName, "the second logout erased the persisted data")
    }

    func testPersonalizeAfterLogoutDoesNotJoinPersonalizeInFlightFromBeforeLogout() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter, personalizeStarted: started, releasePersonalize: release)

        let first = Task { await self.personalize() }
        await Task.detached { started.wait() }.value
        // logout while the first personalize is in flight (the subservice reset a depersonalize performs)
        await withCheckedContinuation { c in
            mobileMessagingInstance.queue.async {
                DepersonalizeOperation.depersonalizeSubservices(userInitiated: true, mmContext: self.mobileMessagingInstance)
                c.resume()
            }
        }
        let second = Task { await self.personalize() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        _ = await first.value
        let secondError = await second.value

        XCTAssertNil(secondError)
        XCTAssertEqual(counter.count, 2, "personalize after logout must not join the request of the previous session")
    }

    func testIdenticalPersonalizeUnderDifferentRegistrationIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter)

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        mobileMessagingInstance.pushRegistrationId = "otherRegistration"
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 2)
    }

    func testIdenticalSaveAfterPersonalizingAnotherUserIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let saves = Counter()
        let stub = personalizeAndDepersonalizeStub(Counter())
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            saves.increment()
            return UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        seedSuccessfulCall(.saveUser, data: saveDebounceKey(for: user))  // identical save just went out

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        let newUser = MobileMessaging.getUser()!
        newUser.firstName = "Darth"
        try await MobileMessaging.saveUser(newUser)

        XCTAssertEqual(saves.count, 1, "a save for the new user must not be dropped as a duplicate of one for the previous user")
    }

    /// Depersonalize R, a fetch shows R attached again, depersonalize R again: the second call must be sent.
    func testDepersonalizeInstallationAgainAfterFetchReattachedItIsSent() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let depersonalizations = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            depersonalizations.increment()
            return DepersonalizeResult.Success(EmptyResponse())
        }
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            let installations = ["pr-0", "pr-1"].map {
                MMInstallation(applicationUserId: nil, appVersion: nil, customAttributes: [:], deviceManufacturer: "Apple", deviceModel: "iPhone", deviceName: $0, deviceSecure: false, deviceTimeZone: nil, isPrimaryDevice: $0 == "pr-0", isPushRegistrationEnabled: true, language: nil, notificationsEnabled: true, os: "iOS", osVersion: "1.2", pushRegistrationId: $0, pushServiceToken: nil, pushServiceType: nil, sdkVersion: nil)
            }
            return FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: nil, middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: installations))
        }
        mobileMessagingInstance.remoteApiProvider = stub

        _ = await depersonalizeInstallation("pr-1")
        _ = try await MobileMessaging.fetchUser()
        XCTAssertNotNil(MobileMessaging.getUser()?.installations?.first(where: { $0.pushRegistrationId == "pr-1" }), "precondition: fetch re-attached pr-1")
        let r = await depersonalizeInstallation("pr-1")

        XCTAssertEqual(depersonalizations.count, 2, "the renewed logout must be submitted")
        XCTAssertNil(r.installations?.first(where: { $0.pushRegistrationId == "pr-1" }))
    }

    // MARK: duplicates while the first call is in flight (no coalescing)

    /// A write is only dropped after an identical write succeeded: a duplicate while the first is still running
    /// is sent (after it, on the serial queue) and reports its own outcome, never a success that did not happen.
    func testDuplicateSaveWhileFirstIsInFlightIsSentAndReportsItsOwnOutcome() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { [retryableError] _, _, _ -> UpdateUserDataResult in
            counter.increment()
            if counter.count == 1 { started.signal(); release.wait() }
            return UpdateUserDataResult.Failure(retryableError)    // every server attempt fails
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "A"
        let save: () async -> NSError? = {
            await withCheckedContinuation { c in MobileMessaging.saveUser(user) { c.resume(returning: $0) } }
        }
        let first = Task { await save() }
        await Task.detached { started.wait() }.value
        let second = Task { await save() }                       // identical, while the first is held
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        let e1 = await first.value, e2 = await second.value

        XCTAssertNotNil(e1)
        XCTAssertNotNil(e2, "the duplicate must not report success when no server write succeeded")
        XCTAssertEqual(counter.count, 2)
    }

    /// A duplicate made while the first personalize is in flight waits behind it on the serial queue and is not
    /// sent once the first succeeded; both callers succeed.
    func testDuplicatePersonalizeWhileFirstIsInFlightIsSentOnce() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            counter.increment()
            if counter.count == 1 { started.signal(); release.wait() }
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let first = Task { await self.personalize() }
        await Task.detached { started.wait() }.value
        let second = Task { await self.personalize() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        let e1 = await first.value, e2 = await second.value

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 1, "the duplicate is dropped once the first one succeeded")
        _ = await personalize()                                    // right after a success: dropped
        XCTAssertEqual(counter.count, 1)
    }

    /// The first personalize fails while its duplicate waits: the duplicate is sent and reports its own result.
    func testDuplicatePersonalizeWhileFirstIsInFlightIsSentWhenFirstFails() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { [retryableError] _, _, _, _, _, _ -> PersonalizeResult in
            counter.increment()
            if counter.count == 1 {
                started.signal(); release.wait()
                return PersonalizeResult.Failure(retryableError)
            }
            return PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let first = Task { await self.personalize() }
        await Task.detached { started.wait() }.value
        let second = Task { await self.personalize() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        let e1 = await first.value, e2 = await second.value

        XCTAssertNotNil(e1, "the first one reports its failure")
        XCTAssertNil(e2, "the duplicate was sent and reports its own success")
        XCTAssertEqual(counter.count, 2)
    }

    /// A duplicate forced personalize made while the first is in flight is dropped before its forced cleanup, so
    /// the subservices are cleaned up once.
    func testDuplicateForcedPersonalizeWhileFirstIsInFlightCleansUpOnce() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter, personalizeStarted: started, releasePersonalize: release)
        let cleanup = CountingCleanupSubservice(mmContext: mobileMessagingInstance, uniqueIdentifier: "CountingCleanupSubservice")
        mobileMessagingInstance.registerSubservice(cleanup)

        let first = Task { await self.forcedPersonalize() }
        await Task.detached { started.wait() }.value
        let second = Task { await self.forcedPersonalize() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        release.signal()
        let e1 = await first.value, e2 = await second.value

        XCTAssertNil(e1); XCTAssertNil(e2)
        XCTAssertEqual(counter.count, 1, "the duplicate is not sent")
        XCTAssertEqual(cleanup.count, 1, "the duplicate does not clean up the subservices again")
        XCTAssertEqual(MobileMessaging.getUser()?.externalUserId, "externalUserId")
    }

    /// Reads keep Android's behaviour: a duplicate fetch while the first is running is dropped right away.
    func testDuplicateFetchWhileFirstIsInFlightIsDroppedImmediately() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = blockingFetchStub(counter, started: started, release: release) {
            FetchUserDataResult.Success(MMUser.empty)
        }

        let first = Task { await self.fetchUser() }
        await Task.detached { started.wait() }.value
        let second = await fetchUser()                             // completes while the first is still held
        XCTAssertNil(second.error)
        XCTAssertEqual(counter.count, 1)
        release.signal()
        _ = await first.value
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: responses arriving after the SDK was stopped (and restarted)

    func testStopDuringForcedPersonalizeCleanupDoesNotCrashAndCompletesOnce() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeAndDepersonalizeStub(counter)
        let cleanup = HeldCleanupSubservice(mmContext: mobileMessagingInstance, uniqueIdentifier: "HeldCleanupSubservice")
        mobileMessagingInstance.registerSubservice(cleanup)

        let completions = Counter()
        let personalize = Task { () -> NSError? in
            await withCheckedContinuation { c in
                MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: self.identity, userAttributes: nil) {
                    completions.increment()
                    c.resume(returning: $0)
                }
            }
        }
        await Task.detached { cleanup.entered.wait() }.value      // the operation waits for the cleanup now
        mobileMessagingInstance.doStop(nil)                          // stop finishes while the cleanup is held
        cleanup.release.signal()
        _ = await personalize.value
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(counter.count, 0, "a cancelled operation must not send its request after the stop")
    }


    func testDepersonalizeInstallationResponseAfterStopAndRestartDoesNotModifyNewInstancesUser() async {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let stub = HeldDepersonalizeApiStub()
        mobileMessagingInstance.remoteApiProvider = stub
        let lock = NSLock()
        var completions = [String: [([MMInstallation]?, NSError?)]]()
        let record: (String) -> (([MMInstallation]?, NSError?)) -> Void = { name in
            { value in lock.lock(); completions[name, default: []].append(value); lock.unlock() }
        }

        let leader = Task { await withCheckedContinuation { c in
            MobileMessaging.depersonalizeInstallation(withPushRegistrationId: "pr-1") { record("leader")(($0, $1)); c.resume() }
        } }
        await Task.detached { stub.started.wait() }.value

        // stop, restart, and give the new instance's user the installation again
        mobileMessagingInstance.doStop(nil)
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()

        stub.release.signal()                                  // old request's success arrives now
        _ = await leader.value
        try? await Task.sleep(nanoseconds: 200_000_000)        // let any late side effect land

        XCTAssertNotNil(MobileMessaging.getUser()?.installations?.first(where: { $0.pushRegistrationId == "pr-1" }),
                        "the stopped instance's response must not modify the new instance's user")
        for name in ["leader"] {
            XCTAssertEqual(completions[name]?.count, 1, "\(name) completed exactly once")
            XCTAssertNil(completions[name]?.first?.0, "\(name) must not get the new instance's installations")
            XCTAssertEqual(completions[name]?.first?.1?.code, NSError(type: .MobileMessagingInstanceNotInitialized).code)
        }
    }

    func testFetchResponseAfterStopAndRestartDoesNotReportNewInstancesUser() async {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        mobileMessagingInstance.remoteApiProvider = blockingFetchStub(counter, started: started, release: release) {
            FetchUserDataResult.Success(MMUser(externalUserId: nil, type: .Lead, firstName: "Fresh", middleName: nil, lastName: nil, phones: nil, emails: nil, tags: nil, gender: nil, birthday: nil, customAttributes: nil, installations: nil))
        }

        let first = Task { await self.fetchUser() }
        await Task.detached { started.wait() }.value
        mobileMessagingInstance.doStop(nil)
        MMTestCase.startWithCorrectApplicationCode()
        await mutateUserLocally("NewInstanceUser")
        release.signal()
        let r = await first.value

        // (the stop cancels the fetch operation, so the caller is usually completed during the stop already)
        XCTAssertNotEqual(r.user?.firstName, "NewInstanceUser", "old caller must not get the new instance's user")
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "NewInstanceUser", "old response must not overwrite it either")
    }

    // MARK: user session report

    func testSentSessionReportIsRememberedByGuard() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        weak let expectation = self.expectation(description: "case is finished")
        var sentBody: RequestBody?
        let stub = RemoteAPIProviderStub()
        stub.sendUserSessionClosure = { _, _, body in
            sentBody = body
            return UserSessionSendingResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
            expectation?.fulfill()
        }

        waitForExpectations(timeout: 20) { _ in
            XCTAssertNotNil(sentBody)
            // an identical report within the window would be dropped
            XCTAssertFalse(self.mobileMessagingInstance.debouncingGuard.shouldAllow(.userSessionReport, data: sentBody))
        }
    }

    func testFailedSessionReportIsNotBlockingRetry() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        weak let expectation = self.expectation(description: "case is finished")
        let counter = Counter()
        var sentBodies = [NSDictionary]()
        let stub = RemoteAPIProviderStub()
        stub.sendUserSessionClosure = { _, _, body in
            counter.increment()
            sentBodies.append(body as NSDictionary)
            return counter.count == 1 ? UserSessionSendingResult.Failure(nil) : UserSessionSendingResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        // clock is frozen, so the second report carries exactly the same body as the failed one
        mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
            self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
                expectation?.fulfill()
            }
        }

        waitForExpectations(timeout: 20) { _ in
            XCTAssertEqual(counter.count, 2)
            XCTAssertEqual(sentBodies.first, sentBodies.last)
        }
    }

    // MARK: cancellation (nil error, but nothing was applied) must not block a retry

    func testIdenticalPersonalizeIsRetriedAfterCancelledRequest() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.personalizeClosure = { _, _, _, _, _, _ -> PersonalizeResult in
            counter.increment()
            return counter.count == 1 ? PersonalizeResult.Cancel : PersonalizeResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        try? await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)
        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 2)
    }

    func testIdenticalSaveUserIsRetriedAfterCancelledRequest() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.patchUserClosure = { _, _, _ -> UpdateUserDataResult in
            counter.increment()
            return counter.count == 1 ? UpdateUserDataResult.Cancel : UpdateUserDataResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        let user = MobileMessaging.getUser()!
        user.firstName = "Darth"
        try? await MobileMessaging.saveUser(user)
        try await MobileMessaging.saveUser(user)

        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(MobileMessaging.getUser()?.firstName, "Darth")
    }

    func testFetchUserIsRetriedAfterCancelledRequest() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.getUserClosure = { _, _ -> FetchUserDataResult in
            counter.increment()
            return counter.count == 1 ? FetchUserDataResult.Cancel : FetchUserDataResult.Success(MMUser.empty)
        }
        mobileMessagingInstance.remoteApiProvider = stub

        _ = try? await MobileMessaging.fetchUser()
        _ = try await MobileMessaging.fetchUser()

        XCTAssertEqual(counter.count, 2)
    }

    func testIdenticalDepersonalizeInstallationIsRetriedAfterCancelledRequest() async {
        MMTestCase.startWithCorrectApplicationCode()
        prepareInstallations()
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
            counter.increment()
            return counter.count == 1 ? DepersonalizeResult.Cancel : DepersonalizeResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        _ = await depersonalizeInstallation("pr-1")
        _ = await depersonalizeInstallation("pr-1")

        XCTAssertEqual(counter.count, 2)
    }

    func testCancelledSessionReportIsNotBlockingRetry() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        weak let expectation = self.expectation(description: "case is finished")
        let counter = Counter()
        let stub = RemoteAPIProviderStub()
        stub.sendUserSessionClosure = { _, _, _ in
            counter.increment()
            return counter.count == 1 ? UserSessionSendingResult.Cancel : UserSessionSendingResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = stub

        mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
            self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
                expectation?.fulfill()
            }
        }

        waitForExpectations(timeout: 20) { _ in
            XCTAssertEqual(counter.count, 2)
        }
    }

    func testPersonalizeCancelledBeforeExecutionIsNotBlockingRetry() async throws {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let counter = Counter()
        mobileMessagingInstance.remoteApiProvider = personalizeStub(counter)

        // hold the queue so the first personalize is still pending when it gets cancelled
        installationQueue.isSuspended = true
        let first = Task {
            try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: self.identity, userAttributes: nil)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        installationQueue.cancelAllOperations()
        installationQueue.isSuspended = false
        _ = try? await first.value

        try await MobileMessaging.personalize(forceDepersonalize: false, keepAsLead: false, userIdentity: identity, userAttributes: nil)

        XCTAssertEqual(counter.count, 1, "only the retry reaches the server")
    }

    // MARK: lifecycle

    func testGuardIsResetOnStop() {
        MMTestCase.startWithCorrectApplicationCode()
        let guardian = mobileMessagingInstance.debouncingGuard
        XCTAssertTrue(guardian.shouldAllow(.personalize, data: ["a": 1]))

        mobileMessagingInstance.doStop(nil)

        XCTAssertTrue(guardian.shouldAllow(.personalize, data: ["a": 1]))
    }
}
