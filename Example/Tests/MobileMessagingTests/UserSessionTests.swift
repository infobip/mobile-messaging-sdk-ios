//
//  UserSessionTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 20.01.2020.
//

import Foundation
import XCTest
@testable import MobileMessaging

class UserSessionTests: MMTestCase {
    
    func testThatUserSessionDataPersisted() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var expectation = self.expectation(description: "case is finished")
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        let now = MobileMessaging.date.now.timeIntervalSince1970
        
        // when
        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
            
            timeTravel(to: Date(timeIntervalSince1970: now + 5), block: {
                
                self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
                    
                    timeTravel(to: Date(timeIntervalSince1970: now + 10), block: {
                        
                        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
                            expectation?.fulfill()
                        }
                    })
                }
            })
        }
        
        // then
        waitForExpectations(timeout: 20, handler: { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let sessions = UserSessionReportObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(sessions.count, 1) // one unreported session
            XCTAssertEqual(sessions.first!.startDate.timeIntervalSince1970, now)
            XCTAssertEqual(sessions.first!.endDate.timeIntervalSince1970, now + 10)
        })
    }
    
    func testSuccessfulSessionReporting() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var expectation = self.expectation(description: "case is finished")
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendUserSessionClosure = { _, _, _ in
            return UserSessionSendingResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        let now = MobileMessaging.date.now.timeIntervalSince1970
        
        // when
        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
            
            timeTravel(to: Date(timeIntervalSince1970: now + 5), block: {
                
                self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
                    
                    timeTravel(to: Date(timeIntervalSince1970: now + 35), block: {
                        
                        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
                            expectation?.fulfill()
                        }
                    })
                }
            })
        }
        
        // then
        waitForExpectations(timeout: 20, handler: { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let sessions = UserSessionReportObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(sessions.count, 1) // one unreported session remains, one should be removed
            XCTAssertEqual(sessions.first!.startDate.timeIntervalSince1970, now + 35)
            XCTAssertEqual(sessions.first!.endDate.timeIntervalSince1970, now + 40)
        })
    }
    
    func testFailedSessionReporting() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var expectation = self.expectation(description: "case is finished")
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendUserSessionClosure = { _, _, _ in
            return UserSessionSendingResult.Failure(nil)
        }
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        let now = MobileMessaging.date.now.timeIntervalSince1970
        
        // when
        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
            
            timeTravel(to: Date(timeIntervalSince1970: now + 5), block: {
                
                self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
                    
                    timeTravel(to: Date(timeIntervalSince1970: now + 35), block: {
                        
                        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
                            expectation?.fulfill()
                        }
                    })
                }
            })
        }
        
        // then
        waitForExpectations(timeout: 20, handler: { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let sessions = UserSessionReportObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(sessions.count, 2)
            
            XCTAssertNotNil(sessions.first { (o) -> Bool in
                return (o.startDate.timeIntervalSince1970 == now + 35) && (o.endDate.timeIntervalSince1970 == now + 40)
            })
            XCTAssertNotNil(sessions.first { (o) -> Bool in
                return (o.startDate.timeIntervalSince1970 == now) && (o.endDate.timeIntervalSince1970 == now + 5)
            })
            
        })
    }
    
    func testSessionReportDoesNotHaveSessionDuplicates() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var expectation = self.expectation(description: "case is finished")
        
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendUserSessionClosure = { _, _, _ in
            return UserSessionSendingResult.Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        let now = MobileMessaging.date.now.timeIntervalSince1970
        
        // when
        mobileMessagingInstance.pushRegistrationId = "reg1"
        self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
            self.mobileMessagingInstance.pushRegistrationId = "reg2"
            self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: false) {
                
                timeTravel(to: Date(timeIntervalSince1970: now + 35), block: {
                    
                    self.mobileMessagingInstance.userSessionService.performSessionTracking(doReporting: true) {
                        expectation?.fulfill()
                    }
                })
            }
        }
        
        // then
        waitForExpectations(timeout: 20, handler: { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let sessions = UserSessionReportObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(sessions.count, 1) // one unreported session remains
        })
    }
    
    func testDegradationUserSessionMapperCrashesWhenTwoSessionStartedWithinSecond() {
        MMTestCase.startWithCorrectApplicationCode()
        let d1 = Date()
        let d2 = Date().addingTimeInterval(0.1)
        let ctx = self.storage.mainThreadManagedObjectContext!
        let s1 = UserSessionReportObject.MM_createEntityInContext(context: ctx)
        s1.pushRegistrationId = "1"
        s1.startReported = false
        s1.startDate = d1
        s1.endDate = d2
        let s2 = UserSessionReportObject.MM_createEntityInContext(context: ctx)
        s2.pushRegistrationId = "2"
        s2.startReported = false
        s2.startDate = d2
        s2.endDate = d2
        waitForExpectations(timeout: 5, handler: { _ in
            XCTAssertNotNil(UserSessionMapper.requestPayload(newSessions: [], finishedSessions: [s1, s2]))
        })
    }
}
