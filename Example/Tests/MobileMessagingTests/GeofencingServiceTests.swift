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
let expectedStartMillisNumber = NSNumber(longLong: 1470388816000)
let expectedStartMillisString = "1470388816000"

let expectedExpiryDateString = "2016-08-06T12:20:16+03:00"
let expectedExpiryMillisNumber = NSNumber(longLong: 1470475216000)
let expectedExpiryMillisString = "1470475216000"

var expectedStartDate: NSDate {
	let comps = NSDateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 5
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = NSTimeZone(forSecondsFromGMT: 3*60*60) // has expected timezone
	comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
	return comps.date!
}

var expectedExpiryDate: NSDate {
	let comps = NSDateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = NSTimeZone(forSecondsFromGMT: 3*60*60) // has expected timezone
	comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
	return comps.date!
}

var notExpectedDate: NSDate {
	let comps = NSDateComponents()
	comps.year = 2016
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16
	comps.timeZone = NSTimeZone(forSecondsFromGMT: 60*60) // has different (not expected) timezone
	comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
	return comps.date!
}

var baseAPNSDict: [String: AnyObject] {
	return
		[
			MMAPIKeys.kMessageId: "123",
	        MMAPIKeys.kAps: [
				MMAPIKeys.kContentAvailable: 1
			]
		]
}

var baseInternalDataDict: [String: AnyObject] {
	return
		[
			MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
			MMAPIKeys.kMessageType: MMAPIKeys.kGeo
		]
}


// modern:
let modernZagrebDict: [String: AnyObject] = [
	MMRegionDataKeys.StartDate.rawValue: expectedStartDateString,
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.ExpiryDate.rawValue: expectedExpiryDateString,
	MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
	MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
	MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
	MMRegionDataKeys.Radius.rawValue: 9492.0,
	MMRegionDataKeys.Title.rawValue: "Zagreb"
]

let modernPulaDict: [String: AnyObject] = [
	MMRegionDataKeys.StartDate.rawValue: expectedStartDateString,
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.ExpiryDate.rawValue: expectedExpiryDateString,
	MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
	MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
	MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
	MMRegionDataKeys.Radius.rawValue: 5257.0,
	MMRegionDataKeys.Title.rawValue: "Pula"
]

var modernInternalDataWithZagrebPulaDict: [String: AnyObject] {
	var result = baseInternalDataDict
	result[MMAPIKeys.kGeo] = [modernZagrebDict, modernPulaDict]
	return result
}

var modernAPNSPayloadZagrebPulaDict: [String: AnyObject] {
	return (baseAPNSDict + [MMAPIKeys.kInternalData: modernInternalDataWithZagrebPulaDict])!
}

// legacy:
let oldZagrebDict: [String: AnyObject] = [
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
	MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
	MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
	MMRegionDataKeys.Radius.rawValue: 9492.0,
	MMRegionDataKeys.Title.rawValue: "Zagreb"
]

let oldPulaDict: [String: AnyObject] = [
	MMRegionDataKeys.ExpiryMillis.rawValue: expectedExpiryMillisNumber,
	MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
	MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
	MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
	MMRegionDataKeys.Radius.rawValue: 5257.0,
	MMRegionDataKeys.Title.rawValue: "Pula"
]

var oldInternalDataZagrebPulaDict: [String: AnyObject] {
	var result = baseInternalDataDict
	result[MMAPIKeys.kGeo] = [oldZagrebDict, oldPulaDict]
	return result
}

var oldmodernAPNSPayloadZagrebPulaDict: [String: AnyObject] {
	return (baseAPNSDict + [MMAPIKeys.kInternalData: oldInternalDataZagrebPulaDict])!
}

// jsons
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
		"\"radiusInMeters\": 9492.0," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"startTime\": \""+expectedStartDateString+"\"," +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257.0," +
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
		"\"radiusInMeters\": 9492.0," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257.0," +
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
		"\"radiusInMeters\": 9492.0," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"expiry\": "+expectedExpiryMillisString+"," +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257.0," +
		"\"title\": \"Pula\"" +
		"}" +
		"]" +
		"}" +
"}"


func makeApnsPayloadWithoutRegionsDataDict() -> [String: AnyObject] {
	return (baseAPNSDict + [MMAPIKeys.kInternalData: baseInternalDataDict])!
}

func makeApnsPayloadWithPulaDict(withEvents events: [AnyObject]?, deliveryTime: AnyObject?) -> [String: AnyObject] {
	var result = makeApnsPayloadWithoutRegionsDataDict()
	var internalData = result[MMAPIKeys.kInternalData] as! [String: AnyObject]
	internalData[MMAPIKeys.kGeo] = [makePulaRegionDict(withEvents: events, deliveryTime: deliveryTime)]
	result[MMAPIKeys.kInternalData] = internalData
	return result
}

func makeEventDict(ofType type: MMRegionEventType, limit: Int, timeout: Int? = nil) -> [String: AnyObject] {
	var result: [String: AnyObject] = [MMRegionEventDataKeys.eventType.rawValue: type.rawValue,
	        MMRegionEventDataKeys.eventLimit.rawValue: limit]
	result[MMRegionEventDataKeys.eventTimeout.rawValue] = timeout
	return result
}

func makeDeliveryTimeDict(withTimeIntervalString timeInterval: String? = nil, daysString days: String? = nil) -> [String: AnyObject]? {
	var result = [String: AnyObject]()
	result[MMRegionDeliveryTimeKeys.timeInterval.rawValue] = timeInterval
	result[MMRegionDeliveryTimeKeys.days.rawValue] = days
	return result.isEmpty ? nil : result
}

var defaultEvent = ["limit": 1, "rate": 0, "timeoutInMinutes": 0, "type": "entry"]

func makePulaRegionDict(withEvents events: [AnyObject]?, deliveryTime: AnyObject?) -> [String: AnyObject] {
	let expiryDateString = NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(NSDate.distantFuture())
	var result = modernPulaDict
	result[MMRegionDataKeys.ExpiryDate.rawValue] = expiryDateString
	result[MMRegionDataKeys.Event.rawValue] = events ?? [defaultEvent]
	result[MMRegionDataKeys.deliveryTime.rawValue] = deliveryTime
	return result
}

class GeofencingServiceTests: MMTestCase {
	
//	func testThatGeoPushIsPassedToTheGeoService() {
//		mobileMessagingInstance.geofencingService = GeofencingServiceAlwaysRunningStub(storage: storage)
//		let expectation = expectationWithDescription("Check finished")
//		self.mobileMessagingInstance.didReceiveRemoteNotification(modernAPNSPayloadZagrebPulaDict, newMessageReceivedCallback: nil, completion: { result in
//			expectation.fulfill()
//		})
//		self.waitForExpectationsWithTimeout(100, handler: { error in
//			XCTAssertEqual(MobileMessaging.geofencingService?.allRegions.count, 2)
//		})
//	}
	
	func testThatGeoPushIsPassedToTheGeoService() {
		mobileMessagingInstance.geofencingService = GeofencingServiceAlwaysRunningStub(storage: storage)
		let expectation = expectationWithDescription("Check finished")
		self.mobileMessagingInstance.didReceiveRemoteNotification(modernAPNSPayloadZagrebPulaDict, newMessageReceivedCallback: nil, completion: { result in
			
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				expectation.fulfill()
			})
		})
		self.waitForExpectationsWithTimeout(100, handler: { error in
			XCTAssertEqual(MobileMessaging.geofencingService?.allRegions.count, 2)
		})
	}
	
	func testCampaignAPNSConstructors() {
		if let message = MMGeoMessage(payload: modernAPNSPayloadZagrebPulaDict, createdDate: NSDate()) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = modernZagrebDict[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, modernZagrebDict[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, modernZagrebDict[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, modernZagrebDict[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, modernZagrebDict[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = modernPulaDict[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, modernPulaDict[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, modernPulaDict[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, modernPulaDict[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, modernPulaDict[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(pulaObject.isLive)
		} else {
			XCTFail()
		}
	}
	
	func testOldCampaignAPNSConstructors() {
		if let message = MMGeoMessage(payload: oldmodernAPNSPayloadZagrebPulaDict, createdDate: NSDate()) {
			var regionsDict = [String: MMRegion]()
			for region in message.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = modernZagrebDict[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.startDate, NSDate(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, modernZagrebDict[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, modernZagrebDict[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, modernZagrebDict[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, modernZagrebDict[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = modernPulaDict[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.startDate, NSDate(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, modernPulaDict[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, modernPulaDict[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, modernPulaDict[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, modernPulaDict[MMRegionDataKeys.Title.rawValue] as? String)
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
			XCTAssertEqual(zagrebObject.radius, 9492.0)
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
			XCTAssertEqual(pulaObject.radius, 5257.0)
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
			XCTAssertEqual(zagrebObject.startDate, NSDate(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.startDate, NSDate(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
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
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.isLive)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.isLive)
			
		} else {
			XCTFail()
		}
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernPulaDict)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernZagrebDict)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernPulaDict))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernZagrebDict))
	}
	
	func testOldDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldPulaDict)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldZagrebDict)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernPulaDict))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernZagrebDict))
	}
	
	func testNullableInitializer() {
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 0, title: "region", expiryDateString: "", startDateString: "", deliveryTime: nil, events: []))
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 1, title: "region", expiryDateString: "", startDateString: expectedStartDateString, deliveryTime: nil, events: []))
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 1, title: "region", expiryDateString: expectedExpiryDateString, startDateString: "", deliveryTime: nil, events: []))
	}
	
//MARK: - Events tests
	func testDefaultEventsSettings() {
		guard let message = MMGeoMessage(payload: makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: nil), createdDate: NSDate()) else
		{
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.first!
		
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
	}
	
	func testOnlyOneEventType() {
		let payload = makeApnsPayloadWithPulaDict(withEvents: [makeEventDict(ofType: .exit, limit: 1, timeout: 0)], deliveryTime: nil)
		
		guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.first!
		
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
	}
	
	func testGeoMessageTypeCasting() {
		let geoMessagePayload = makeApnsPayloadWithPulaDict(withEvents: [makeEventDict(ofType: .exit, limit: 1, timeout: 0)], deliveryTime: nil)
		let geoMsg = MMMessageFactory.makeMessage(with: geoMessagePayload, createdDate: NSDate())
		XCTAssertTrue(geoMsg is MMGeoMessage)
		
		let regularMessagePayload = makeApnsPayloadWithoutRegionsDataDict()
		let msg = MMMessageFactory.makeMessage(with: regularMessagePayload, createdDate: NSDate())
		XCTAssertFalse(msg is MMGeoMessage)
	}
	
	func testEventsOccuring() {
		let timeoutInMins: Int = 1
		
		let payload = makeApnsPayloadWithPulaDict(withEvents: [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins),
												   makeEventDict(ofType: .exit, limit: 2, timeout: timeoutInMins)], deliveryTime: nil)
		guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.first!
		
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
		
		// move the event into the past for 1 minute
		pulaObject.events.forEach { (event) in
			event.lastOccuring = NSDate(timeIntervalSinceNow: -Double(timeoutInMins) * Double(60))
		}
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
	}
	
	func testEventLimitZero() {
		
		let payload = makeApnsPayloadWithPulaDict(withEvents: [makeEventDict(ofType: .entry, limit: 0, timeout: 0),
												   makeEventDict(ofType: .exit, limit: 0, timeout: 0)], deliveryTime: nil)
		guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.first!
		
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		for _ in 0 ..< 10 {
			pulaObject.triggerEvent(for: .entry)
			XCTAssertTrue(pulaObject.isLive(for: .entry))
			XCTAssertTrue(pulaObject.isLive(for: .exit))
		}
	}
	
	func testEventTimeoutNotSet() {
		
		let payload = makeApnsPayloadWithPulaDict(withEvents: [makeEventDict(ofType: .entry, limit: 1),
			makeEventDict(ofType: .exit, limit: 1)], deliveryTime: nil)
		guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.first!
		
		XCTAssertTrue(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))

		pulaObject.triggerEvent(for: .entry)
		XCTAssertFalse(pulaObject.isLive(for: .entry))
		XCTAssertTrue(pulaObject.isLive(for: .exit))
		
		pulaObject.triggerEvent(for: .exit)
		XCTAssertFalse(pulaObject.isLive(for: .exit))
	}
	
//MARK: - delivery time tests
	
	func testAbsentDeliveryWindow() {
		let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: nil)
		guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.first!
		
		XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
		XCTAssertFalse(pulaObject.isNowAppropriateTimeForExitNotification)
	}

	
//	func testParticularDeliveryWindows() {
//		
//		let testDate: NSDate = {
//			let comps = NSDateComponents()
//			comps.year = 2016
//			comps.month = 10
//			comps.day = 9
//			comps.hour = 12
//			comps.minute = 20
//			comps.timeZone = NSTimeZone(forSecondsFromGMT: 3*60*60) // has expected timezone
//			comps.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
//			return comps.date!
//		}()
//		
//		let sunday = "7"
//		let thursdaySunday = "4,7"
//		let monday = "1"
//
//		timeTravel(to: testDate) {
//			// appropriate day, time not set
//			do {
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			do {
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			// appropriate time, day not set
//			do {
//				let timeIntervalString = "1200/1230"
//
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			do {
//				let timeIntervalString = "2300/1230"
//	
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			// appropriate day and time
//			do {
//				let timeIntervalString = "1200/1230"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			do {
//				let timeIntervalString = "2300/1230"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertTrue(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			
//			// inappropriate day
//			do {
//				let timeIntervalString = "1200/1230"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			do {
//				let timeIntervalString = "2300/1230"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			
//			// inappropriate time
//			do {
//				let timeIntervalString = "0000/1215"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			
//			do {
//				let timeIntervalString = "1230/2335"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			
//			// inappropriate day and time
//			do {
//				let timeIntervalString = "0000/1215"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			do {
//				let timeIntervalString = "1230/2335"
//				let payload = makeApnsPayloadWithPulaDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday))
//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
//					XCTFail()
//					return
//				}
//				let pulaObject = message.regions.first!
//				XCTAssertFalse(pulaObject.isNowAppropriateTimeForEntryNotification)
//			}
//			
//		}
//	}
	
	func testTimeWindowDictRepresentations() {
		let timeIntervalString = "0000/1215"
		let friday = "5"
		var payload = makePulaRegionDict(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: friday))
		
		let dictRepresentation = MMRegion(dictRepresentation: payload)!.dictionaryRepresentation
		XCTAssertNotNil(MMRegion(dictRepresentation: dictRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: payload))
		payload[MMRegionDataKeys.ExpiryMillis.rawValue] = nil // dict representation must not contain the ExpiryMillis field (deprecated one)
		XCTAssertTrue((dictRepresentation as NSDictionary).isEqual(payload as NSDictionary))
	}
}
