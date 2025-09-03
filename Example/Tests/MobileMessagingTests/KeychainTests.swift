//
//  KeychainTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 01.09.2025.
//

import XCTest
@testable import MobileMessaging

class KeychainTests: XCTestCase {
    
    override class func setUp() {
        let nonsharedKeychain = MMKeychain(accessGroup: nil)
        nonsharedKeychain.clear()
        
        let sharedKeychain = MMKeychain(accessGroup: Bundle.mainAppBundle.appGroupId)
        sharedKeychain.clear()
    }
    
    override class func tearDown() {
        let nonsharedKeychain = MMKeychain(accessGroup: nil)
        nonsharedKeychain.clear()
        
        let sharedKeychain = MMKeychain(accessGroup: Bundle.mainAppBundle.appGroupId)
        sharedKeychain.clear()
    }
    
    func testThatNonSharedKeychainDataIsMigratedToSharedKeychain() {
        let nonsharedKeychain = MMKeychain(accessGroup: nil)
        nonsharedKeychain.applicationCode = "appcode"
        nonsharedKeychain.pushRegId = "pushRegId"
        
        let sharedKeychain = MMKeychain(accessGroup: Bundle.mainAppBundle.appGroupId)
        
        XCTAssertEqual("appcode", sharedKeychain.applicationCode)
        XCTAssertEqual("pushRegId", sharedKeychain.pushRegId)
        XCTAssertNil(nonsharedKeychain.applicationCode)
        XCTAssertNil(nonsharedKeychain.pushRegId)
    }
}
