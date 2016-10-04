//
//  GeofencingServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/08/16.
//

import XCTest
import CoreLocation
import SwiftyJSON
@testable import MobileMessaging

class GeofencingServiceAlwaysRunningStub: MMGeofencingService {
	override var isRunning: Bool {
		set {
			
		}
		get {
			return true
		}
	}
}

let expectedStartDateString = "2016-08-05T12:20:16+03:00"
let expectedStartMillisNumber = NSNumber(value: 1470388816000)
let expectedStartMillisString = "1470388816000"

let expectedExpiryDateString = "2016-08-06T12:20:16+03:00"
let expectedExpiryMillisNumber = NSNumber(value: 1470475216000)
let expectedExpiryMillisString = "1470475216000"

var expectedStartDate: Date {
	var comps = DateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 5
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = TimeZone(secondsFromGMT: 3*60*60) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}

var expectedExpiryDate: Date {
	var comps = DateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = TimeZone(secondsFromGMT: 3*60*60) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}

var notExpectedDate: Date {
	var comps = DateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = TimeZone(secondsFromGMT: 60*60) // has different (not expected) timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date!
}

let zagreb: DictionaryRepresentation = [
	MMRegionDataKeys.StartDate.rawValue: expectedStartDateString,
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.ExpiryDate.rawValue: expectedExpiryDateString,
	MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
	MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
	MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
	MMRegionDataKeys.Radius.rawValue: 9492.0,
	MMRegionDataKeys.Title.rawValue: "Zagreb"
]

let pula: DictionaryRepresentation = [
	MMRegionDataKeys.StartDate.rawValue: expectedStartDateString,
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.ExpiryDate.rawValue: expectedExpiryDateString,
	MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
	MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
	MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
	MMRegionDataKeys.Radius.rawValue: 5257.0,
	MMRegionDataKeys.Title.rawValue: "Pula"
]

var internalData: DictionaryRepresentation {
	return [
		MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
		MMAPIKeys.kMessageType: MMAPIKeys.kGeo,
		MMAPIKeys.kGeo: [zagreb, pula]
	]
}

var apnsPayload: DictionaryRepresentation {
	return [
		"messageId": "123",
		"aps": [
			"content-available": 1
		],
		MMAPIKeys.kInternalData: internalData
	]
}

let oldZagreb: DictionaryRepresentation = [
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
	MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
	MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
	MMRegionDataKeys.Radius.rawValue: 9492.0,
	MMRegionDataKeys.Title.rawValue: "Zagreb"
]

let oldPula: DictionaryRepresentation = [
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
	MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
	MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
	MMRegionDataKeys.Radius.rawValue: 5257.0,
	MMRegionDataKeys.Title.rawValue: "Pula"
]

var oldInternalData: DictionaryRepresentation {
	return [
		MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
		MMAPIKeys.kMessageType: MMAPIKeys.kGeo,
		MMAPIKeys.kGeo: [oldZagreb, oldPula]
	]
}

var oldapnsPayload: DictionaryRepresentation {
	return [
		"messageId": "123",
		"aps": [
			"content-available": 1
		],
		MMAPIKeys.kInternalData: oldInternalData
	]
}

let jsonStr =
	"{" +
		"\"aps\": { \"content-available\": 1}," +
		"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
		"\"internalData\": {" +
		"\"silent\": { \"body\": \"campaign text\"}," +
		"\"geo\": [" +
		"{" +
		"\"startTime\": \""+expectedStartDateString+"\"," +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
		"\"latitude\": 45.80869126677998," +
		"\"longitude\": 15.97206115722656," +
		"\"radiusInMeters\": 9492," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"startTime\": \""+expectedStartDateString+"\"," +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257," +
		"\"title\": \"Pula\"" +
		"}" +
		"]" +
		"}" +
"}"

let jsonStrWithoutStartTime =
	"{" +
		"\"aps\": { \"content-available\": 1}," +
		"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
		"\"internalData\": {" +
		"\"silent\": { \"body\": \"campaign text\"}," +
		"\"geo\": [" +
		"{" +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
		"\"latitude\": 45.80869126677998," +
		"\"longitude\": 15.97206115722656," +
		"\"radiusInMeters\": 9492," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257," +
		"\"title\": \"Pula\"" +
		"}" +
		"]" +
		"}" +
"}"

let oldjsonStr =
	"{" +
		"\"aps\": { \"content-available\": 1}," +
		"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
		"\"internalData\": {" +
		"\"silent\": { \"body\": \"campaign text\"}," +
		"\"geo\": [" +
		"{" +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
		"\"latitude\": 45.80869126677998," +
		"\"longitude\": 15.97206115722656," +
		"\"radiusInMeters\": 9492," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257," +
		"\"title\": \"Pula\"" +
		"}" +
		"]" +
		"}" +
"}"


func makeApnsPayload() -> DictionaryRepresentation {
	let internalData: DictionaryRepresentation = [
		MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
		MMAPIKeys.kMessageType: MMAPIKeys.kGeo
	]
	let payload: DictionaryRepresentation = [
		"messageId": "123",
		"aps": [ "content-available": 1],
		MMAPIKeys.kInternalData: internalData
	]
	return payload
}
func makeApnsPayload(withEvents events: [DictionaryRepresentation]?) -> DictionaryRepresentation {
	let internalData: DictionaryRepresentation = [
		MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
		MMAPIKeys.kMessageType: MMAPIKeys.kGeo,
		MMAPIKeys.kGeo: [makePulaRegion(withEvents: events)]
	]
	let payload: DictionaryRepresentation = [
		"messageId": "123",
		"aps": [ "content-available": 1],
		MMAPIKeys.kInternalData: internalData
	]
	return payload
}

func makeEvent(ofType type: MMRegionEventType, limit: Int, timeout: Int) -> DictionaryRepresentation {
	return [MMRegionEventDataKeys.eventType.rawValue: type.rawValue,
	        MMRegionEventDataKeys.eventLimit.rawValue: limit,
	        MMRegionEventDataKeys.eventTimeout.rawValue: timeout]
}

func makeEvent(ofType type: MMRegionEventType, limit: Int) -> DictionaryRepresentation {
	return [MMRegionEventDataKeys.eventType.rawValue: type.rawValue,
	        MMRegionEventDataKeys.eventLimit.rawValue: limit]
}

func makePulaRegion(withEvents events: [DictionaryRepresentation]?) -> DictionaryRepresentation {
	let expiryDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date.distantFuture)
	
	let events: Any = events ?? NSNull()
	return [
		MMRegionDataKeys.ExpiryDate.rawValue: expiryDateString,
		MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
		MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
		MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
		MMRegionDataKeys.Radius.rawValue: 5257.0,
		MMRegionDataKeys.Title.rawValue: "Pula",
		MMRegionDataKeys.Event.rawValue: events
	]
}

class GeofencingServiceTests: MMTestCase {
	
	func testThatGeoPushIsPassedToTheGeoService() {
		mobileMessagingInstance.geofencingService = GeofencingServiceAlwaysRunningStub(storage: storage)
		let expectation = self.expectation(description: "Check finished")
		self.mobileMessagingInstance.didReceiveRemoteNotification(apnsPayload, newMessageReceivedCallback: nil, completion: { result in
			expectation.fulfill()
		})
		self.waitForExpectations(timeout: 100, handler: { error in
			XCTAssertEqual(MobileMessaging.geofencingService?.allRegions.count, 2)
		})
	}
	
	func testCampaignAPNSConstructors() {
		if let message = MMGeoMessage(payload: apnsPayload, createdDate: Date()) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = zagreb[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, zagreb[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, zagreb[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, zagreb[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, zagreb[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = pula[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, pula[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, pula[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, pula[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, pula[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(pulaObject.isLive)
		} else {
			XCTFail()
		}
	}
	

	func testOldCampaignAPNSConstructors() {
		if let message = MMGeoMessage(payload: oldapnsPayload, createdDate: Date()) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = zagreb[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.startDate, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, zagreb[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, zagreb[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, zagreb[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, zagreb[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = pula[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.startDate, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, pula[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, pula[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, pula[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, pula[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(pulaObject.isLive)
		} else {
			XCTFail()
		}
	}
	
	func testCampaignJSONConstructors() {
		let json = JSON.parse(jsonStr)
	
		if let message = MMGeoMessage(json: json) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.startDate, expectedStartDate)
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.startDate, expectedStartDate)
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.isLive)
			
		} else {
			XCTFail()
		}
	}
	
	func testCampaignJSONConstructorsWithoutStartTime() {
		let json = JSON.parse(jsonStrWithoutStartTime)
		
		if let message = MMGeoMessage(json: json) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.startDate, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.startDate, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.isLive)
			
		} else {
			XCTFail()
		}
	}
	
	func testOldCampaignJSONConstructors() {
		let json = JSON.parse(oldjsonStr)
		
		if let message = MMGeoMessage(json: json) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.isLive)
			
		} else {
			XCTFail()
		}
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: pula))
		XCTAssertNotNil(MMRegion(dictRepresentation: zagreb))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: pula)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: zagreb)!.dictionaryRepresentation))
	}
	
	func testOldDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: oldPula))
		XCTAssertNotNil(MMRegion(dictRepresentation: oldZagreb))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldPula)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldZagreb)!.dictionaryRepresentation))
	}
	
	func testNullableInitializer() {
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 0, title: "region", expiryDateString: "", startDateString: ""))
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 1, title: "region", expiryDateString: "", startDateString: expectedStartDateString))
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 1, title: "region", expiryDateString: expectedExpiryDateString, startDateString: ""))
	}
	
	//MARK: Events tests
	func testDefaultEventsSettings() {
		guard let message = MMGeoMessage(payload: makeApnsPayload(withEvents: nil), createdDate: Date()) else {
			XCTFail()
			return
		}
		var regionsDict = [String: MMRegion]()
		for region in message.regions {
			regionsDict[region.identifier] = region
		}
		let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
		let pulaObject = regionsDict[pulaId]!
		
		XCTAssertEqual(pulaObject.identifier, pulaId)
		XCTAssertEqual(pulaObject.title, "Pula")
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
	}
	
	func testOnlyOneEventType() {
		let payload = makeApnsPayload(withEvents: [makeEvent(ofType: .exit, limit: 1, timeout: 0)])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		var regionsDict = [String: MMRegion]()
		message.regions.forEach { region in
			regionsDict[region.identifier] = region
		}
		let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
		let pulaObject = regionsDict[pulaId]!
		
		XCTAssertEqual(pulaObject.identifier, pulaId)
		XCTAssertEqual(pulaObject.title, "Pula")
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
	}
	
	func testGeoMessageTypeCasting() {
		let geoMessagePayload = makeApnsPayload(withEvents: [makeEvent(ofType: .exit, limit: 1, timeout: 0)])
		let geoMsg = MMMessageFactory.makeMessage(with: geoMessagePayload, createdDate: Date())
		XCTAssertTrue(geoMsg is MMGeoMessage)
		
		let regularMessagePayload = makeApnsPayload()
		let msg = MMMessageFactory.makeMessage(with: regularMessagePayload, createdDate: Date())
		XCTAssertFalse(msg is MMGeoMessage)
	}
	
	func testEventsOccuring() {
		let timeoutInMins: Int = 1
		
		let payload = makeApnsPayload(withEvents: [makeEvent(ofType: .entry, limit: 2, timeout: timeoutInMins),
												   makeEvent(ofType: .exit, limit: 2, timeout: timeoutInMins)])
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		var regionsDict = [String: MMRegion]()
		for region in message.regions {
			regionsDict[region.identifier] = region
		}
		let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
		let pulaObject = regionsDict[pulaId]!
		
		
		XCTAssertEqual(pulaObject.identifier, pulaId)
		XCTAssertEqual(pulaObject.title, "Pula")
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		// move the event into the past for 1 minute
		pulaObject.events.forEach { (event) in
			event.lastOccur = Date(timeIntervalSinceNow: -Double(timeoutInMins) * Double(60))
		}
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
	}
	
	func testEventLimitZero() {
		
		let payload = makeApnsPayload(withEvents: [makeEvent(ofType: .entry, limit: 0, timeout: 0),
												   makeEvent(ofType: .exit, limit: 0, timeout: 0)])
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		var regionsDict = [String: MMRegion]()
		message.regions.forEach { region in
			regionsDict[region.identifier] = region
		}
		let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
		let pulaObject = regionsDict[pulaId]!
		
		XCTAssertEqual(pulaObject.identifier, pulaId)
		XCTAssertEqual(pulaObject.title, "Pula")
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		for _ in 0 ..< 10 {
			pulaObject.triggerEvent(for: .entry)
			XCTAssertTrue(pulaObject.isLive(for: .entry))
			XCTAssertTrue(pulaObject.isLive(for: .exit))
		}
	}
	
	func testEventTimeoutNotSet() {
		
		let payload = makeApnsPayload(withEvents: [makeEvent(ofType: .entry, limit: 1),
			makeEvent(ofType: .exit, limit: 1)])
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		var regionsDict = [String: MMRegion]()
		for region in message.regions {
			regionsDict[region.identifier] = region
		}
		let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
		let pulaObject = regionsDict[pulaId]!
		
		XCTAssertEqual(pulaObject.identifier, pulaId)
		XCTAssertEqual(pulaObject.title, "Pula")
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))

		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
	}
}
