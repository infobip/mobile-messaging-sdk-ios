//
//  MMGeofencingServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/08/16.
//

import XCTest
import CoreLocation
@testable import MobileMessaging

class GeofencingServiceTests: MMTestCase {
    
	func testRealSignalingPayloadParsing() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let p: MMAPNSPayload =
			[
				"messageId": "kOvQTcsXuLlLiD4jrB+tGqF1aPOoY+WbLi98ftMvlh0=",
				"internalData": [
					"geo": [
						[
							"id": "E35D739EDB3AF20F265AB567AE60485E",
							"title": "SPB Office LARGE",
							"radiusInMeters": 290,
							"latitude": 59.961086185895155,
							"longitude": 30.303305643050862
						]
					],
					"messageType": "geo",
					"campaignId": "803487",
					"expiryTime": "2017-07-04T17:00:00Z",
					"events": [
						[
							"type": "entry",
							"limit": 0,
							"timeoutInMinutes": 0
						]
					],
					"silent": [
						"body": "Text2"
					]
				],
				"aps": [
					"alert": [
						"body": "Text2"
					]
				],
				"silent": true
		]
		XCTAssertNotNil(MMGeoMessage(payload: p, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false))
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatTwoSequentalCampaignsAppearTwice() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var expectationCampaign = self.expectation(description: "")
		weak var didReceiveRemoteNotification1 = self.expectation(description: "didReceiveRemoteNotification")
		weak var didReceiveRemoteNotification2 = self.expectation(description: "didReceiveRemoteNotification2")
		MMGeofencingService.currentDate = expectedStartDate
		var counter = 0
		let zagreb = CLLocation(latitude: 45.80869126677998, longitude: 15.97206115722656)
		let geoStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance, locationManagerStub: LocationManagerStub(locationStub: zagreb))
		geoStub.didEnterRegionCallback = { region in
			counter += 1
			if counter == 2 {
				expectationCampaign?.fulfill()
			}
		}
		MMGeofencingService.sharedInstance = geoStub
		MMGeofencingService.sharedInstance!.start({ _ in
			let m1 = (baseAPNSDict(messageId: "m1") + [Consts.APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: m1,  completion: { _ in
				didReceiveRemoteNotification1?.fulfill()
			})

			let m2 = (baseAPNSDict(messageId: "m2") + [Consts.APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: m2,  completion: { _ in
				didReceiveRemoteNotification2?.fulfill()
			})
		})
		self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testThatGeoPushIsPassedToTheGeoService() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		weak var expectation = self.expectation(description: "Check finished")
		
		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: modernAPNSPayloadZagrebPulaDict,  completion: { _ in
			//Should be in main because Geofensing service saves data asynchronously in main
			DispatchQueue.main.async {
				expectation?.fulfill()
			}
		})
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(MobileMessaging.geofencingService?.allRegions.count, 2)
		})
	}
	
	func testAbsentStartDate() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		var apnsPayload = modernAPNSPayloadZagrebPulaDict
		var internalData = apnsPayload[Consts.APNSPayloadKeys.internalData] as! [String: AnyObject]
		internalData[GeoConstants.CampaignKeys.startDate] = nil
		apnsPayload[Consts.APNSPayloadKeys.internalData] = internalData
		if let message = MMGeoMessage(payload: apnsPayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) {
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(message.startTime, Date(timeIntervalSinceReferenceDate: 0))
		} else {
			XCTFail()
		}
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testCampaignAPNSConstructors() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let apnsPayload = modernAPNSPayloadZagrebPulaDict
		
		if let message = MMGeoMessage(payload: apnsPayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) {
			
			let zagrebId = modernZagrebDict[GeoConstants.RegionKeys.identifier] as! String
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqual(zagrebObject.center.latitude, modernZagrebDict[GeoConstants.RegionKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.center.longitude, modernZagrebDict[GeoConstants.RegionKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, modernZagrebDict[GeoConstants.RegionKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, modernZagrebDict[GeoConstants.RegionKeys.title] as? String)
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaId = modernPulaDict[GeoConstants.RegionKeys.identifier] as! String
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqual(pulaObject.center.latitude, modernPulaDict[GeoConstants.RegionKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.center.longitude, modernPulaDict[GeoConstants.RegionKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, modernPulaDict[GeoConstants.RegionKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, modernPulaDict[GeoConstants.RegionKeys.title] as? String)
			XCTAssertFalse(pulaObject.message!.isNotExpired)
		} else {
			XCTFail()
		}
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testCampaignJSONConstructors() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let json = JSON.parse(jsonStr)
		
		if let message = MMGeoMessage(messageSyncResponseJson: json) {
			
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqual(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqual(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.message!.isNotExpired)
			
		} else {
			XCTFail()
		}
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testCampaignJSONConstructorsWithoutStartTime() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let json = JSON.parse(jsonStrWithoutStartTime)
		
		if let message = MMGeoMessage(messageSyncResponseJson: json) {
			
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqual(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqual(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.message!.isNotExpired)
			
		} else {
			XCTFail()
		}
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation))
	}
	
	//MARK: - Events tests
	func testDefaultEventsSettings() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else
		{
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertFalse(message.isLiveNow(for: .exit))

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)

				report1?.fulfill()
			}
			
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)

				report2?.fulfill()
			}
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testOnlyOneEventType() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .exit, limit: 1, timeout: 0)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		XCTAssertFalse(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in

			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				report1?.fulfill()
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
			}
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				report2?.fulfill()
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
			}
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}

	func testEventsOccuring() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		weak var report3 = expectation(description: "report3")
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins),
					  makeEventDict(ofType: .exit, limit: 2, timeout: timeoutInMins)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		let zagrebObject = message.regions.findZagreb
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			let group = DispatchGroup()
			group.enter()
			group.enter()
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertTrue(msg!.isLiveNow(for: .exit))
				
				report1?.fulfill()
				group.leave()
			}
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertFalse(msg!.isLiveNow(for: .exit))
				
				report2?.fulfill()
				group.leave()
			}

			group.notify(queue: DispatchQueue.main) {

				// move to the future
				MMGeofencingService.currentDate = Date(timeIntervalSinceNow: Double(timeoutInMins) * Double(60))
				
				// so that they look alive again
				XCTAssertTrue(message.isLiveNow(for: .entry))
				XCTAssertTrue(message.isLiveNow(for: .exit))
				
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: zagrebObject.identifier, geoMessage: message) { state in
					XCTAssertEqual(MMCampaignState.Active, state)
					let msg = MobileMessaging.geofencingService!.datasource.messages.first
					XCTAssertFalse(msg!.isLiveNow(for: .entry))
					XCTAssertTrue(msg!.isLiveNow(for: .exit))
					
					report3?.fulfill()
				}
			}
		})
		
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testEventLimitZero() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = succeedingApiStub

		let events = [makeEventDict(ofType: .entry, limit: 0, timeout: 0),
					  makeEventDict(ofType: .exit, limit: 0, timeout: 0)]
		
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		let group = DispatchGroup()
		
		for _ in 0 ..< 10 {
			group.enter()
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				group.leave()
			}
			XCTAssertTrue(message.isLiveNow(for: .entry))
			XCTAssertTrue(message.isLiveNow(for: .exit))
		}
		
		
		weak var exp = expectation(description: "finished")
		group.notify(queue: DispatchQueue.main) { 
			exp?.fulfill()
		}
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testEventTimeoutNotSet() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .entry, limit: 1),
					  makeEventDict(ofType: .exit, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertTrue(msg!.isLiveNow(for: .exit))
				report1?.fulfill()
			}
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
				report2?.fulfill()
			}
		})
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testReportSentOnlyOnce() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .entry, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
        
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload) { _ in
			let validEntryRegions = MMGeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)
			
			MobileMessaging.geofencingService?.report(on: .entry, forRegionId: pulaId, geoMessage: message, completion: { (s) in
				report1?.fulfill()
			})
			
            MobileMessaging.geofencingService?.syncWithServer(completion: { (result) in
				if let result = result {
					switch result {
					case .Cancel: report2?.fulfill()
                    case .Failure(let er): XCTFail(er?.localizedDescription ?? "n/a")
					default: XCTFail("Success sync result not expected")
					}
				} else { XCTFail() }
			})
		}
		
		waitForExpectations(timeout: 20) { _ in
			if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(events.count, 0)
			}
		}
	}
	
	//MARK: - delivery time tests
	
	func testAbsentDeliveryWindow() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
		XCTAssertFalse(message.isNowAppropriateTimeForExitNotification)
        self.waitForExpectations(timeout: 20, handler: nil)
	}

	func testParticularDeliveryWindows() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let testDate_09_10_2016__12_20_GMT: Date = {
			let comps = NSDateComponents()
			comps.year = 2016
			comps.month = 10
			comps.day = 9
			comps.hour = 12
			comps.minute = 20
			comps.timeZone = TimeZone(secondsFromGMT: 0)
			comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
			return comps.date!
		}()
		
		MobileMessaging.timeZone = TimeZone(abbreviation: "GMT")!
		
		let sunday = "7"
		let thursdaySunday = "4,7"
		let monday = "1"

		timeTravel(to: testDate_09_10_2016__12_20_GMT) {
			// appropriate day, time not set
			do {
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			// appropriate time, day not set
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			// appropriate day and time
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate day
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate time
			do {
				let timeIntervalString = "0000/1215"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			do {
				let timeIntervalString = "1230/2335"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate day and time
			do {
				let timeIntervalString = "0000/1215"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "1230/2335"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

		}
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testTimeWindowDictRepresentations() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let timeIntervalString = "0000/1215"
		let friday = "5"
		let apnsPayload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: friday), regions: [modernPulaDict, modernZagrebDict])
		
		let dictRepresentation = MMGeoMessage(payload: apnsPayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!.originalPayload
		XCTAssertNotNil(MMGeoMessage(payload: dictRepresentation, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false))
		XCTAssertTrue((dictRepresentation as NSDictionary).isEqual(apnsPayload as NSDictionary))
        self.waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testGeoEventsStorageSuccessfullyReported() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
		// triggers 2 events and mocks successfull reportings wich ends up with an empty events storage
		generalTestForPersistingEventReports(with: succeedingApiStub, expectedEventsCount: 0)
	}

	func testGeoEventsStorageUnsuccessfullyReported() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
		// triggers 2 events and mocks failed reportings wich ends up with an events storage containing 2 records
		generalTestForPersistingEventReports(with: failingApiStub, expectedEventsCount: 2)
	}

	func testThatReportsAreBeingSentToTheServerWithCorrectData() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else
		{
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		let zagrebObject = message.regions.findZagreb

		var reportSentCounter = 0
		weak var eventReported = self.expectation(description: "eventReported")
		var sentCampaignIds = Set<String>()
		var sentMessageIds = Set<String>()
		var sentGeoAreaIds = Set<String>()
		var sentEventTypes = Set<String>()

		// expect remote api queue called
		let remoteAPIMock = RemoteGeoAPIProviderStub()
		remoteAPIMock.reportGeoEventClosure = { _, _, eventsDataList, geoMessages -> GeoEventReportingResult in

			if let report = eventsDataList.first {
				sentCampaignIds.insert(report.campaignId)
				sentGeoAreaIds.insert(report.geoAreaId)
				sentEventTypes.insert(report.eventType.rawValue)
				sentMessageIds.insert(report.messageId)
			}

			let geoMessage = geoMessages.first!
			XCTAssertEqual(geoMessage.campaignId, expectedCampaignId)
			XCTAssertEqual(geoMessage.messageId, expectedMessageId)

			reportSentCounter += 1

			if reportSentCounter == 2 {
				XCTAssertTrue(sentCampaignIds.contains(expectedCampaignId))
				XCTAssertEqual(sentCampaignIds.count, 1)

				XCTAssertTrue(sentGeoAreaIds.contains(zagrebId))
				XCTAssertTrue(sentGeoAreaIds.contains(pulaId))
				XCTAssertEqual(sentGeoAreaIds.count, 2)

				XCTAssertTrue(sentEventTypes.contains(RegionEventType.entry.rawValue))
				XCTAssertTrue(sentEventTypes.contains(RegionEventType.exit.rawValue))
				XCTAssertEqual(sentEventTypes.count, 2)

				XCTAssertTrue(sentMessageIds.contains(expectedMessageId))
				XCTAssertEqual(sentMessageIds.count, 1)

				eventReported?.fulfill()
			}
			return GeoEventReportingResult.Success(GeoEventReportingResponse(json: JSON.parse(
				"""
				{
					"messageIds": {
						"tm1": "m1",
						"tm2": "m2",
						"tm3": "m3"
					}
				}
			"""
			))!)
		}

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = remoteAPIMock

		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			// simulate entry event
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				report1?.fulfill()
			}
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: zagrebObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				report2?.fulfill()
			}
		})

		self.waitForExpectations(timeout: 10, handler: nil)
	}

	func testSuspendedCampaigns() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = self.expectation(description: "report1")
		weak var messageReceived = self.expectation(description: "messageReceived")
		
		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })

		let remoteApiProvider = RemoteGeoAPIProviderStub()
		remoteApiProvider.reportGeoEventClosure =  { _, _, eventsDataList, _ -> GeoEventReportingResult in
			let jsonStr: String

			if eventsDataList.first?.campaignId == suspendedCampaignId {
				jsonStr = "{\"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"}, \"suspendedCampaignIds\": [\"\(suspendedCampaignId)\"]}"
			} else if eventsDataList.first?.campaignId == finishedCampaignId {
				jsonStr = "{\"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"}, \"finishedCampaignIds\": [\"\(finishedCampaignId)\"]}"
			} else {
				jsonStr = ""
			}
			return GeoEventReportingResult.Success(GeoEventReportingResponse(json: JSON.parse(jsonStr))!)
		}

		MMGeofencingService.sharedInstance!.remoteApiProvider = remoteApiProvider

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict], campaignId: suspendedCampaignId)
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula

		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in

			messageReceived?.fulfill()

			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
				XCTAssertEqual(MMCampaignState.Suspended, state)
				report1?.fulfill()
			})
		})
		
		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testFinishedCampaigns() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var report1 = expectation(description: "report1")

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict], campaignId: finishedCampaignId)
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				let pulaObject = message.regions.findPula
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in

					XCTAssertEqual(MMCampaignState.Finished, state)
					let ctx = self.storage.mainThreadManagedObjectContext!
					ctx.reset()
					let message = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "campaignId == %@", finishedCampaignId), context: ctx)

					XCTAssertEqual(MMCampaignState.Finished, message?.campaignState)
					report1?.fulfill()

				})
			}
		})

		waitForExpectations(timeout: 60, handler: nil)
	}

	func testEventNotOccuredAgaingAfterRestartTheService() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var messageExp = expectation(description: "messageExp")
		weak var reportExp = expectation(description: "reportExp")

		let oldDatasource = MobileMessaging.geofencingService!.datasource
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()
		mobileMessagingInstance.messageHandler = MessagHandlerMock(originalHandler: mobileMessagingInstance.messageHandler)

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			messageExp?.fulfill()

			let pulaObject = message.regions.findPula

			XCTAssertTrue(message.isLiveNow(for: .entry))

			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(MMCampaignState.Active, state)

				//Check that occurence count was saved in DB
				DispatchQueue.main.async {
					MobileMessaging.geofencingService?.datasource = GeofencingInMemoryDatasource(storage: self.storage)
                    XCTAssertTrue(oldDatasource == nil)
					let messageAfterEvent = MobileMessaging.geofencingService?.datasource.messages.first
					let region = messageAfterEvent?.regions.first
					XCTAssertNotNil(region)
					XCTAssertEqual(region!.radius, pulaObject.radius)
					XCTAssertEqual(region!.identifier, pulaObject.identifier)
					XCTAssertEqual(region!.message?.events.first?.occuringCounter, 1)
					XCTAssertNotNil(region!.message?.events.first?.lastOccuring)
					XCTAssertFalse(messageAfterEvent!.isLiveNow(for: .entry))
					reportExp?.fulfill()
				}
			}
		})
		waitForExpectations(timeout: 60, handler: nil)
	}

	func testThatDidEnterRegionTriggers2EventsFor2CampaignsWithSameRegions() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var didEnterRegionExp = expectation(description: "didEnterRegionExp")

		var didEnterRegionCount = 0
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payloadOfCampaign1 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId1", messageId: "messageId1")
		let payloadOfCampaign2 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId2", messageId: "messageId2")

		guard let message1 = MMGeoMessage(payload: payloadOfCampaign1, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false),
			let message2 = MMGeoMessage(payload: payloadOfCampaign2, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
				XCTFail()
				return
		}

		var enteredDatasourceRegions = [MMRegion]()

		let geoServiceStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		geoServiceStub.didEnterRegionCallback = { (region) in
			didEnterRegionCount += 1
			enteredDatasourceRegions.append(region)
			if didEnterRegionCount == 2 {
				XCTAssertTrue(enteredDatasourceRegions.contains(message1.regions.first!))
				XCTAssertTrue(enteredDatasourceRegions.contains(message2.regions.first!))
				didEnterRegionExp?.fulfill()
			}
		}

		MMGeofencingService.sharedInstance = geoServiceStub
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = succeedingApiStub
		geoServiceStub.stubbedLocationManager.locationStub = CLLocation(latitude: 45.80869126677998, longitude: 15.97206115722656)
		geoServiceStub.add(message: message1) {}
		geoServiceStub.add(message: message2) {}

		geoServiceStub.locationManager(geoServiceStub.stubbedLocationManager, didEnterRegion: message1.regions.findPula.circularRegion)

		waitForExpectations(timeout: 60, handler: nil)
	}

	func testThatRegionsAreNotDuplicatedInTheMonitoredRegions() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var didEnterRegionExp = expectation(description: "didEnterRegionExp")

		var didEnterRegionCount = 0
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payloadOfCampaign1 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId1", messageId: "messageId3")
		let payloadOfCampaign2 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId2", messageId: "messageId4")

		guard let message1 = MMGeoMessage(payload: payloadOfCampaign1, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false),
			let message2 = MMGeoMessage(payload: payloadOfCampaign2, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
				XCTFail()
				return
		}

		let pulaObject1 = message1.regions.findPula
		let pulaObject2 = message2.regions.findPula


		let geoServiceStub: GeofencingServiceAlwaysRunningStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		geoServiceStub.didEnterRegionCallback = { (region) in
			didEnterRegionCount += 1
			if didEnterRegionCount == 1 {
				XCTAssertEqual(region.dataSourceIdentifier, pulaObject1.dataSourceIdentifier)
				let monitoredRegionsArray = geoServiceStub.stubbedLocationManager.monitoredRegionsArray
				XCTAssertEqual(monitoredRegionsArray.count, 1)
			} else  if didEnterRegionCount == 2 {
				XCTAssertEqual(region.dataSourceIdentifier, pulaObject2.dataSourceIdentifier)
				let monitoredRegionsArray = geoServiceStub.stubbedLocationManager.monitoredRegionsArray
				XCTAssertEqual(monitoredRegionsArray.count, 1)
				didEnterRegionExp?.fulfill()
			}
		}

		MMGeofencingService.sharedInstance = geoServiceStub
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = succeedingApiStub

		geoServiceStub.stubbedLocationManager.locationStub = CLLocation(latitude: pulaObject1.center.latitude, longitude: pulaObject1.center.longitude)
		geoServiceStub.add(message: message1) {}
		geoServiceStub.add(message: message2) {}

		waitForExpectations(timeout: 60, handler: nil)
	}

	func testThatVirtualGeoMessagesCreated() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: "none", finishedCampaignId: "none") {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 1, expectedAllMessagesCount: 2)
		})
	}
	
	func testThatVirtualGeoMessageHasGeoAreaData() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: "none", finishedCampaignId: "none") {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				ctx.reset()
				if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
					
					let msg = allMsgs.filter({ (msg) -> Bool in
						return msg.messageId == "ipcoremessageid" && msg.payload != nil && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.NotSeen && msg.campaignId == nil
					}).first
					
					XCTAssertNotNil((msg?.payload?["internalData"] as? DictionaryRepresentation)?["geo"] as? [DictionaryRepresentation])
				} else {
					XCTFail()
				}
			}
		})
	}
	
	func testThatVirtualGeoMessagesNotCreatedForSuspendedCampaign() {
        MMTestCase.startWithCorrectApplicationCode()

		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: expectedCampaignId, finishedCampaignId: "none") {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 0, expectedAllMessagesCount: 1)
		})
	}

	func testThatVirtualGeoMessagesNotCreatedForFinishedCampaign() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: "none", finishedCampaignId: expectedCampaignId) {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 0, expectedAllMessagesCount: 1)
		})
	}
	
	private func testVirtualGeoMessages(suspendedCampaignId: String, finishedCampaignId: String, completion: @escaping () -> Void) {
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
		let geoSignalingMessagePayload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let geoSignalingMessage = MMGeoMessage(payload: geoSignalingMessagePayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = geoSignalingMessage.regions.findPula
		var sentSdkMessageId: String!
        mobileMessagingInstance.pushRegistrationId = "rand"

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })

		let remoteApiProvider = RemoteGeoAPIProviderStub()
		remoteApiProvider.reportGeoEventClosure = { _, pushRegId, geoEventReportDataList, messages -> GeoEventReportingResult in
			let report = geoEventReportDataList.first
			let message = messages.first

			XCTAssertEqual(pushRegId, "rand")

			XCTAssertEqual(report?.campaignId, expectedCampaignId)
			XCTAssertEqual(report?.geoAreaId, pulaObject.identifier)
			XCTAssertEqual(report?.eventType, RegionEventType.entry)
			XCTAssertEqual(report?.messageId, expectedMessageId)

			sentSdkMessageId = report!.sdkMessageId
			XCTAssertTrue(sentSdkMessageId.mm_isUUID)

			XCTAssertEqual(message?.messageId, expectedMessageId)
			XCTAssertEqual(message?.text, expectedCampaignText)
			XCTAssertEqual(message?.isSilent, true)
			XCTAssertEqual(message?.sound, expectedSound)
			XCTAssertNil(message?.title)
			XCTAssertNil(message?.badge)
			XCTAssertNotNil(message?.internalData)


			let jsonStr  =
			"""
			{
			"finishedCampaignIds": ["\(finishedCampaignId)"],
			"suspendedCampaignIds": ["\(suspendedCampaignId)"],
			"messageIds": {
			"\(sentSdkMessageId!)": "ipcoremessageid"
			}
			}
			"""
			return GeoEventReportingResult.Success(GeoEventReportingResponse(json: JSON.parse(jsonStr))!)

		}
		MMGeofencingService.sharedInstance!.remoteApiProvider = remoteApiProvider

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: geoSignalingMessagePayload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: geoSignalingMessage, completion: { state in
					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
						completion()
					})
				})
			}
		})
	}
	
	func testOfflineGeoEventsHandling() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var notReachableTest = expectation(description: "test finished (w/o internet)")
		weak var reachableTest = expectation(description: "test finished (w/ internet)")
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}

		let pulaObject = message.regions.findPula

		self.storage.mainThreadManagedObjectContext!.MM_saveToPersistentStoreAndWait()

		let checkNotReachableExpectations = {
			let ctx = self.storage.mainThreadManagedObjectContext!

			ctx.performAndWait {
				ctx.reset()
				if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
					XCTAssertEqual(allMsgs.count, 2)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						return msg.messageId == expectedMessageId
					}).count, 1)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						// here we expect a message in the storage that has a sdk generated message id, because we had no internet connection to get a real one
						return msg.messageId.mm_isSdkGeneratedMessageId && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.NotSeen && msg.campaignId == nil
					}).count, 1)
				} else {
					XCTFail()
				}
			}
		}

		let checkReachableExpectations = {
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				ctx.reset()
				if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
					XCTAssertEqual(allMsgs.count, 2)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						return msg.messageId == expectedMessageId
					}).count, 1)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						// here we expect a message in the storage that has a real message id (generated by our backend)
						return msg.messageId == "ipcoremessageid" && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.NotSeen && msg.campaignId == nil
					}).count, 1)
				} else {
					XCTFail()
				}
			}
		}

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				// at this point there must be no internet:
				MobileMessaging.geofencingService!.remoteApiProvider = self.defaultRemoteApiProvider(isOffline: true)
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in

					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
						notReachableTest?.fulfill()
						checkNotReachableExpectations()

						// now turn the internet on:
						MobileMessaging.geofencingService!.remoteApiProvider = self.defaultRemoteApiProvider(isOffline: false)

						// and sync geo service to report on non-reported geo events
						MobileMessaging.geofencingService!.syncWithServer(completion: { _ in
							DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
								checkReachableExpectations()
								reachableTest?.fulfill()
							})
						})
					})
				})
			}
		})

		waitForExpectations(timeout: 60, handler: nil)
	}

	private func defaultRemoteApiProvider(isOffline: Bool? = false) -> RemoteGeoAPIProviderStub {
		let remoteApiProvider = RemoteGeoAPIProviderStub()
		remoteApiProvider.isOffline = isOffline ?? false
		remoteApiProvider.reportGeoEventClosure = { _, _, geoEventReportDataList, _ -> GeoEventReportingResult in
			let sentSdkMessageId = geoEventReportDataList.first!.sdkMessageId
			let jsonStr  = """
			{
			"finishedCampaignIds": [\"\(finishedCampaignId)\"],
			"suspendedCampaignIds": [\"\(suspendedCampaignId)\"],
			"messageIds": {
			"\(sentSdkMessageId)": "ipcoremessageid"
			}
			}
			"""
			return GeoEventReportingResult.Success(GeoEventReportingResponse(json: JSON.parse(jsonStr))!)
		}
		return remoteApiProvider
	}

	func testSetSeenForSdkGeneratedMessages() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		// we expect that none seen status updates will be sent to the server until the real message id is retrieved
		weak var notReachableTest = expectation(description: "test finished (w/o internet)")
		weak var seenForSdkGeneratedIdCompleted = expectation(description: "seenForSdkGeneratedIdCompleted")
		weak var seenForRealIdCompleted = expectation(description: "seenForRealIdCompleted")
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		let checkSeenPersistanceExpectations = {
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				ctx.reset()
				if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
					XCTAssertEqual(allMsgs.count, 2)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						return msg.messageId == expectedMessageId
					}).count, 1)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						// here we expect a message in the storage that has a sdk generated message id, because we had no internet connection to get a real one
						return msg.messageId.mm_isSdkGeneratedMessageId && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.SeenNotSent && msg.campaignId == nil
					}).count, 1)
				} else {
					XCTFail()
				}
			}
		}

		let checkSeenPersistanceAfterSuccessfullEventReportingExpectations = {
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				ctx.reset()
				if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
					XCTAssertEqual(allMsgs.count, 2)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						return msg.messageId == expectedMessageId
					}).count, 1)

					XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
						// here we expect a message in the storage that has a real message id, it was retrieved by the successful geo reporting
						// seen status was succesfully updated because set seen does support real message ids
						return msg.messageId == "ipcoremessageid" && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.SeenSent && msg.campaignId == nil
					}).count, 1)
				} else {
					XCTFail()
				}

				if let allEvents = GeoEventReportObject.MM_findAllInContext(ctx) {
					XCTAssertTrue(allEvents.isEmpty)
				} else {
					XCTFail()
				}
			}
		}

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.sendSeenStatusClosure = { _, _, _ -> SeenStatusSendingResult in
			XCTFail() // the seen must not be sent, there are only sdk generated message ids, which have no sense to be marked as seen
			return SeenStatusSendingResult.Failure(MMInternalErrorType.UnknownError.foundationError)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()
        
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				// at this point there must be no internet:
				var sentSdkMessageId: String!
				let remoteApiProvider = RemoteGeoAPIProviderStub()
				remoteApiProvider.isOffline = true
				remoteApiProvider.reportGeoEventClosure = { _, _, geoEventReportDataList, _ -> GeoEventReportingResult in
					sentSdkMessageId = geoEventReportDataList.first!.sdkMessageId
					let jsonStr  = """
					{
					"finishedCampaignIds": [\"\(finishedCampaignId)\"],
					"suspendedCampaignIds": [\"\(suspendedCampaignId)\"],
					"messageIds": {
					"\(sentSdkMessageId!)": "ipcoremessageid"
					}
					}
					"""
					return GeoEventReportingResult.Success(GeoEventReportingResponse(json: JSON.parse(jsonStr))!)
				}
				MMGeofencingService.sharedInstance!.remoteApiProvider = remoteApiProvider

				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in

					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
						notReachableTest?.fulfill()

						// now turn the internet on:
						MMGeofencingService.sharedInstance!.remoteApiProvider = self.defaultRemoteApiProvider(isOffline: false)

						// now lets try to set seen on the sdk generated message id
                        self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: [sentSdkMessageId], immediately: false, completion: {
							checkSeenPersistanceExpectations()
							seenForSdkGeneratedIdCompleted?.fulfill()

							self.mobileMessagingInstance.remoteApiProvider = RemoteAPIProviderStub()
							// now sync geo service to report on non-reported geo events and get real message ids
							MobileMessaging.geofencingService!.syncWithServer(completion: { _ in
								checkSeenPersistanceAfterSuccessfullEventReportingExpectations()
								seenForRealIdCompleted?.fulfill()
							})
						})
					})
				})
			}
		})

		waitForExpectations(timeout: 60, handler: nil)
	}

	func testThatGeneratedMessageHasAppropriateInternalDataFromSignalingMesage() {
		guard let payload = JSON.parse(jsonStr).dictionaryObject,
			let geoMessage = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else
		{
			XCTFail()
			return
		}

		let mt = MM_MTMessage.make(fromGeoMessage: geoMessage, messageId: "", region: geoMessage.regions.first!)
		XCTAssertTrue(mt!.showInApp)
		XCTAssertEqual(mt!.inAppStyle, MMInAppNotificationStyle.Banner)
		XCTAssertFalse(mt!.isGeoSignalingMessage)
        XCTAssertEqual(mt!.contentUrl, expectedContentUrl)
        XCTAssertEqual(mt!.webViewUrl?.absoluteString, expectedInAppWebViewUrl)
        XCTAssertEqual(mt!.browserUrl?.absoluteString, expectedInAppBrowserUrl)
        XCTAssertEqual(mt!.deeplink?.absoluteString, expectedInAppDeeplink)
        XCTAssertEqual(mt!.inAppDismissTitle, expectedInAppDismissBtnTitle)
        XCTAssertEqual(mt!.inAppOpenTitle, expectedInAppOpenBtnTitle)
        XCTAssertEqual(mt!.title, expectedCampaignTitle)
        XCTAssertEqual(mt!.text, expectedCampaignText)
        XCTAssertEqual(mt!.sound, expectedSound)
	}
    
    func testThatGeneratedMessageHasAppropriateInternalDataFromSignalingMesageFromPushUp() {
        guard let payload = JSON.parse(jsonStrFromPushUp).dictionaryObject,
            let geoMessage = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else
        {
            XCTFail()
            return
        }

        let mt = MM_MTMessage.make(fromGeoMessage: geoMessage, messageId: "", region: geoMessage.regions.first!)
        XCTAssertTrue(mt!.showInApp)
        XCTAssertEqual(mt!.inAppStyle, MMInAppNotificationStyle.Banner)
        XCTAssertFalse(mt!.isGeoSignalingMessage)
        XCTAssertEqual(mt!.contentUrl, expectedContentUrl)
        XCTAssertEqual(mt!.webViewUrl?.absoluteString, expectedInAppWebViewUrl)
        XCTAssertEqual(mt!.browserUrl?.absoluteString, expectedInAppBrowserUrl)
        XCTAssertEqual(mt!.deeplink?.absoluteString, expectedInAppDeeplink)
        XCTAssertEqual(mt!.inAppDismissTitle, expectedInAppDismissBtnTitle)
        XCTAssertEqual(mt!.inAppOpenTitle, expectedInAppOpenBtnTitle)
        XCTAssertEqual(mt!.title, expectedCampaignTitle)
        XCTAssertEqual(mt!.text, expectedCampaignText)
        XCTAssertEqual(mt!.sound, expectedSound)
    }

	func testHandlingOfFetchedGeoPayload() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		let regionId = "7867EB6623F628AE2EC71EF3135A2B29"
		let jsonFromPushUp = "{\"messageId\": \"rCpFVUbewlXjnHGu4ZmnuDQTEtvX7moFrWM80jYMhEE=\",\"customPayload\": {},\"internalData\": {\"geo\": [{\"id\": \"\(regionId)\",\"title\": \"SPB Office\",\"radiusInMeters\": 102,\"latitude\": 59.96102588813523,\"longitude\": 30.304096912685168,\"favorite\": false}],\"messageType\": \"geo\",\"campaignId\": \"770789\",\"expiryTime\": \"2017-06-29T10:15:00+00:00\",\"silent\": {\"body\": \"fetching geo test 111\",\"sound\": \"default\"}},\"aps\": {\"alert\": {\"body\": \"fetching geo test 111\"}},\"silent\": true}"

		guard let payload = JSON.parse(jsonFromPushUp).dictionaryObject,
			let message = MM_MTMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false),
			let geoMessage = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
				XCTFail()
				return
		}

		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")

		let messageHandlingDelegateMock = MessageHandlingDelegateMock()
		messageHandlingDelegateMock.willScheduleLocalNotification = { m in
			XCTAssertEqual(m.text, message.text)
			report2?.fulfill()
		}

		MobileMessaging.messageHandlingDelegate = messageHandlingDelegateMock

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = defaultRemoteApiProvider()
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload) { _ in
			MobileMessaging.geofencingService?.report(on: .entry, forRegionId: regionId, geoMessage: geoMessage, completion: { result in
				report1?.fulfill()
			})
		}

		waitForExpectations(timeout: 50) { error in
			if error != nil { XCTFail() }
			if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(events.count, 0)
			}
		}
	}

	func testThatAmongConcurringNestedAreasThatUserIsAlreadyInTheSmallestOneWins() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var didEnterExpectation = self.expectation(description: "")
		MMGeofencingService.currentDate = expectedStartDate
		let pulaCaffeLocation = CLLocation(latitude: 44.86803631018752, longitude: 13.84586334228516)
		let geoStub = GeofencingServiceAlwaysRunningStub(
			mmContext: self.mobileMessagingInstance,
			locationManagerStub: LocationManagerStub(locationStub: pulaCaffeLocation)
		)

		var didEnterRegionCount = 0
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let campaignPayload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, nestedPulaDict], campaignId: "nested_regions_campaign", messageId: "messageId1")
		let message1 = MMGeoMessage(payload: campaignPayload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!

		geoStub.didEnterRegionCallback = { region in
			didEnterRegionCount += 1
		}
		MMGeofencingService.sharedInstance = geoStub
		MMGeofencingService.sharedInstance!.start({ _ in })

		MMGeofencingService.sharedInstance?.add(message: message1) {}

		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5), execute: {
			didEnterExpectation?.fulfill()
		})

		self.waitForExpectations(timeout: 500, handler: { _ in
			XCTAssertEqual(1, didEnterRegionCount)
		})
	}

	//MARK: - Private helpers
	private func generalTestForPersistingEventReports(with apiMock: RemoteGeoAPIProviderStub, expectedEventsCount: Int) {

		weak var eventsDatabaseCheck1 = self.expectation(description: "eventsDatabaseCheck1")
		weak var messageReceived = self.expectation(description: "messageReceived")

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else
		{
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula

		// expect remote api queue called
		mobileMessagingInstance.pushRegistrationId = "rand"

		MMGeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		MMGeofencingService.sharedInstance!.start({ _ in })
		MMGeofencingService.sharedInstance!.remoteApiProvider = apiMock

		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in

			messageReceived?.fulfill()

			// simulate entry event
			let reportSendingGroup = DispatchGroup()
			reportSendingGroup.enter()
			reportSendingGroup.enter()

			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				reportSendingGroup.leave()
			})

			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message, completion:  { state in
				XCTAssertEqual(MMCampaignState.Active, state)
				reportSendingGroup.leave()
			})

			reportSendingGroup.notify(queue: DispatchQueue.main) {
				// check events database (must be 0)
				if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
					XCTAssertEqual(events.count, expectedEventsCount)
					eventsDatabaseCheck1?.fulfill()
				} else {
					XCTFail()
				}
			}
		})

		self.waitForExpectations(timeout: 60, handler: nil)
	}

	private func checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: Int, expectedAllMessagesCount: Int) {
		let ctx = self.storage.mainThreadManagedObjectContext!
		ctx.performAndWait {
			ctx.reset()
			if let allMsgs = MessageManagedObject.MM_findAllInContext(ctx) {
				XCTAssertEqual(allMsgs.count, expectedAllMessagesCount)
				
				XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
					return msg.messageId == expectedMessageId
				}).count, 1)
				
				XCTAssertEqual(allMsgs.filter({ (msg) -> Bool in
					return msg.messageId == "ipcoremessageid" && msg.payload != nil && msg.reportSent == true && msg.isSilent == false && msg.messageType == MMMessageType.Default && msg.seenStatus == MMSeenStatus.NotSeen && msg.campaignId == nil
				}).count, expectedVirtualMessagesCount)
			} else {
				XCTFail()
			}
		}
	}
}
