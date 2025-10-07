// 
//  Example/Tests/MobileMessagingTests/TrustedDomainsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class TrustedDomainsTests: MMTestCase {
    
    func testWithTrustedDomainsBuilderMethod() {
        let trustedDomains = ["example.com", "trusted.org", "subdomain.example.com"]
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(trustedDomains)
        XCTAssertEqual(mm.trustedDomains, trustedDomains)
    }
    
    func testTrustedDomainsCleanupOnStop() {
        let trustedDomains = ["example.com", "trusted.org"]
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(trustedDomains)
        mm.doStart()
        XCTAssertEqual(mm.trustedDomains, trustedDomains)
        mm.doStop(nil)
        XCTAssertNil(mm.trustedDomains)
    }
    
    func testBackwardCompatibilityWithoutTrustedDomains() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
        mm.doStart()
        XCTAssertNil(mm.trustedDomains)
    }
    
    func testTrustedDomainsArrayCanBeSetToEmpty() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains([])
        mm.doStart()
        XCTAssertNotNil(mm.trustedDomains)
        XCTAssertTrue(mm.trustedDomains!.isEmpty)
    }
    
    func testAllowsAllWhenNoTrustedDomainsAreSet() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://whatever.com")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "http://google.com")!))
    }
    
    func testExactDomainMatch() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(["example.com"])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://example.com")!))
    }
    
    func testSubdomainMatch() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(["example.com"])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://api.example.com")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://foo.bar.example.com")!))
    }
    
    func testPartialMatchDoesNotAllow() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(["example.com"])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertFalse(service.isUrlDomainTrusted(URL(string: "https://evil-example.com")!))
        XCTAssertFalse(service.isUrlDomainTrusted(URL(string: "https://notexample.com")!))
    }
    
    func testMultipleDomainsMatch() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(["foo.com", "bar.org"])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://foo.com/page")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://sub.foo.com/page")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://bar.org/")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://one.bar.org/")!))
        XCTAssertFalse(service.isUrlDomainTrusted(URL(string: "https://baz.com/page")!))
    }
    
    func testEmptyArrayAllowsAllUrls() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains([])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://what.com/ever")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://sub.com/page")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://abc.org/")!))
        XCTAssertTrue(service.isUrlDomainTrusted(URL(string: "https://anywhere.com/foo")!))
    }
    
    func testInvalidUrlOrHost() {
        let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!
            .withTrustedDomains(["example.com"])
        let service = NotificationsInteractionService(mmContext: mm, categories: nil)
        XCTAssertFalse(service.isUrlDomainTrusted(URL(string: "not_a_valid_url")!))
        XCTAssertFalse(service.isUrlDomainTrusted(URL(string: "file:///tmp/readme.txt")!))
    }
}
