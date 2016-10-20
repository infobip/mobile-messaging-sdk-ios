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


extension Set where Element: MMRegion {
	var findPula: MMRegion {
		return self.filter { (region) -> Bool in
			return region.title == "Pula"
			}.first!
	}
	var findZagreb: MMRegion {
		return self.filter { (region) -> Bool in
			return region.title == "Zagreb"
			}.first!
	}
}

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

let expectedExpiryDateString = "2016-08-06T12:20:16+03:00"

var expectedStartDate: Date {
	let comps = NSDateComponents()
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
	let comps = NSDateComponents()
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
	let comps = NSDateComponents()
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

var baseAPNSDict: APNSPayload {
	return
		[
			APNSPayloadKeys.kMessageId: "123",
			APNSPayloadKeys.kAps: [
				APNSPayloadKeys.kContentAvailable: 1
			]
	]
}

var baseInternalDataDict: APNSPayload {
	return
		[
			MMCampaignDataKeys.startDate: expectedStartDateString,
			MMCampaignDataKeys.expiryDate: expectedExpiryDateString,
			APNSPayloadKeys.kInternalDataSilent: [APNSPayloadKeys.kBody: "campaign text"],
			APNSPayloadKeys.kInternalDataMessageType: APNSPayloadKeys.kInternalDataMessageTypeGeo
	]
}


// modern:
let modernZagrebDict: APNSPayload = [
	MMRegionDataKeys.identifier: "6713245DA3638FDECFE448C550AD7681",
	MMRegionDataKeys.latitude: 45.80869126677998,
	MMRegionDataKeys.longitude: 15.97206115722656,
	MMRegionDataKeys.radius: 9492.0,
	MMRegionDataKeys.title: "Zagreb"
]

let modernPulaDict: APNSPayload = [
	MMRegionDataKeys.identifier: "A277A2A0D0612AFB652E9D2D80E02BF2",
	MMRegionDataKeys.latitude: 44.86803631018752,
	MMRegionDataKeys.longitude: 13.84586334228516,
	MMRegionDataKeys.radius: 5257.0,
	MMRegionDataKeys.title: "Pula"
]

var modernInternalDataWithZagrebPulaDict: APNSPayload {
	var result = baseInternalDataDict
	result[APNSPayloadKeys.kInternalDataGeo] = [modernZagrebDict, modernPulaDict]
	return result
}

var modernAPNSPayloadZagrebPulaDict: APNSPayload {
	return (baseAPNSDict + [APNSPayloadKeys.kInternalData: modernInternalDataWithZagrebPulaDict])!
}

// jsons
let jsonStr =
	"{" +
		"\"aps\": { \"content-available\": 1}," +
		"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
		"\"internalData\": {" +
		"\"silent\": { \"body\": \"campaign text\"}," +
		"\"startTime\": \""+expectedStartDateString+"\"," +
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"geo\": [" +
		"{" +
		"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
		"\"latitude\": 45.80869126677998," +
		"\"longitude\": 15.97206115722656," +
		"\"radiusInMeters\": 9492.0," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
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
		"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
		"\"geo\": [" +
		"{" +
		"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
		"\"latitude\": 45.80869126677998," +
		"\"longitude\": 15.97206115722656," +
		"\"radiusInMeters\": 9492.0," +
		"\"title\": \"Zagreb\"" +
		"}," +
		"{" +
		"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
		"\"latitude\": 44.86803631018752," +
		"\"longitude\": 13.84586334228516," +
		"\"radiusInMeters\": 5257.0," +
		"\"title\": \"Pula\"" +
		"}" +
		"]" +
		"}" +
"}"

func makeApnsPayloadWithoutRegionsDataDict() -> APNSPayload {
	return (baseAPNSDict + [APNSPayloadKeys.kInternalData: baseInternalDataDict])!
}

func makeApnsPayload(withEvents events: [APNSPayload]?, deliveryTime: APNSPayload?, regions: [APNSPayload]) -> APNSPayload {
	var result = makeApnsPayloadWithoutRegionsDataDict()
	var internalData = result[APNSPayloadKeys.kInternalData] as! APNSPayload
	internalData[APNSPayloadKeys.kInternalDataGeo] = regions
	internalData[APNSPayloadKeys.kInternalDataEvent] = events ?? [defaultEvent]
	internalData[APNSPayloadKeys.kInternalDataDeliveryTime] = deliveryTime
	let distantFutureDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date.distantFuture)
	internalData[MMCampaignDataKeys.expiryDate] = distantFutureDateString
	result[APNSPayloadKeys.kInternalData] = internalData
	return result
}

func makeEventDict(ofType type: MMRegionEventType, limit: Int, timeout: Int? = nil) -> APNSPayload {
	var result: APNSPayload = [MMRegionEventDataKeys.eventType: type.rawValue,
	                                   MMRegionEventDataKeys.eventLimit: limit]
	result[MMRegionEventDataKeys.eventTimeout] = timeout
	return result
}

func makeDeliveryTimeDict(withTimeIntervalString timeInterval: String? = nil, daysString days: String? = nil) -> APNSPayload? {
	var result = APNSPayload()
	result[MMRegionDeliveryTimeKeys.timeInterval] = timeInterval
	result[MMRegionDeliveryTimeKeys.days] = days
	return result.isEmpty ? nil : result
}

var defaultEvent = ["limit": 1, "rate": 0, "timeoutInMinutes": 0, "type": "entry"] as APNSPayload

class GeofencingServiceTests: MMTestCase {
	
	func testThatGeoPushIsPassedToTheGeoService() {
		mobileMessagingInstance.geofencingService = GeofencingServiceAlwaysRunningStub(storage: storage)
		weak var expectation = self.expectation(description: "Check finished")
		self.mobileMessagingInstance.didReceiveRemoteNotification(modernAPNSPayloadZagrebPulaDict, newMessageReceivedCallback: nil, completion: { result in
			//Should be in main because Geofensing service saves data asynchronously in main
			DispatchQueue.main.async {
				expectation?.fulfill()
			}
		})
		self.waitForExpectations(timeout: 100, handler: { error in
			XCTAssertEqual(MobileMessaging.geofencingService?.allRegions.count, 2)
		})
	}
	
	func testAbsentStartDate() {
		var apnsPayload = modernAPNSPayloadZagrebPulaDict
		var internalData = apnsPayload[APNSPayloadKeys.kInternalData] as! [String: AnyObject]
		internalData[MMCampaignDataKeys.startDate] = nil
		apnsPayload[APNSPayloadKeys.kInternalData] = internalData
		if let message = MMGeoMessage(payload: apnsPayload, createdDate: Date()) {
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(message.startTime, Date(timeIntervalSinceReferenceDate: 0))
		} else {
			XCTFail()
		}
	}
	
	func testCampaignAPNSConstructors() {
		let apnsPayload = modernAPNSPayloadZagrebPulaDict
		
		if let message = MMGeoMessage(payload: apnsPayload, createdDate: Date()) {
			
			let zagrebId = modernZagrebDict[MMRegionDataKeys.identifier] as! String
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, modernZagrebDict[MMRegionDataKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, modernZagrebDict[MMRegionDataKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, modernZagrebDict[MMRegionDataKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, modernZagrebDict[MMRegionDataKeys.title] as? String)
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaId = modernPulaDict[MMRegionDataKeys.identifier] as! String
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, modernPulaDict[MMRegionDataKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, modernPulaDict[MMRegionDataKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, modernPulaDict[MMRegionDataKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, modernPulaDict[MMRegionDataKeys.title] as? String)
			XCTAssertFalse(pulaObject.message!.isNotExpired)
		} else {
			XCTFail()
		}
	}
	
	func testCampaignJSONConstructors() {
		let json = JSON.parse(jsonStr)
		
		if let message = MMGeoMessage(json: json) {
			
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.message!.isNotExpired)
			
		} else {
			XCTFail()
		}
	}
	
	func testCampaignJSONConstructorsWithoutStartTime() {
		let json = JSON.parse(jsonStrWithoutStartTime)
		
		if let message = MMGeoMessage(json: json) {
			
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492.0)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257.0)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertFalse(pulaObject.message!.isNotExpired)
			
		} else {
			XCTFail()
		}
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation))
	}
	
	//MARK: - Events tests
	func testDefaultEventsSettings() {
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else
		{
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLive(for: .entry))
		XCTAssertFalse(message.isLive(for: .exit))
		
		message.triggerEvent(for: .entry, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .entry))
		XCTAssertFalse(message.isLive(for: .exit))
		
		message.triggerEvent(for: .exit, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .exit))
	}
	
	func testOnlyOneEventType() {
		let events = [makeEventDict(ofType: .exit, limit: 1, timeout: 0)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		XCTAssertFalse(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .exit, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .exit))
		
		message.triggerEvent(for: .entry, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .entry))
	}
	
	func testGeoMessageTypeCasting() {
		let events = [makeEventDict(ofType: .exit, limit: 1, timeout: 0)]
		let geoMessagePayload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		let geoMsg = MMMessageFactory.makeMessage(with: geoMessagePayload, createdDate: Date())
		XCTAssertTrue(geoMsg is MMGeoMessage)
		
		let regularMessagePayload = makeApnsPayloadWithoutRegionsDataDict()
		let msg = MMMessageFactory.makeMessage(with: regularMessagePayload, createdDate: Date())
		XCTAssertFalse(msg is MMGeoMessage)
	}
	
	func testEventsOccuring() {
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins),
		              makeEventDict(ofType: .exit, limit: 2, timeout: timeoutInMins)]
		
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		let zagrebObject = message.regions.findZagreb
		
		XCTAssertTrue(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .entry, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .exit, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .exit))
		
		// move the event into the past
		message.events.forEach { (event) in
			event.lastOccuring = Date(timeIntervalSinceNow: -Double(timeoutInMins) * Double(60))
		}
		// so that they look alive again
		XCTAssertTrue(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .entry, region: zagrebObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
	}
	
	func testEventLimitZero() {
		let events = [makeEventDict(ofType: .entry, limit: 0, timeout: 0),
		              makeEventDict(ofType: .exit, limit: 0, timeout: 0)]
		
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		for _ in 0 ..< 10 {
			message.triggerEvent(for: .entry, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
			XCTAssertTrue(message.isLive(for: .entry))
			XCTAssertTrue(message.isLive(for: .exit))
		}
	}
	
	func testEventTimeoutNotSet() {
		let events = [makeEventDict(ofType: .entry, limit: 1),
		              makeEventDict(ofType: .exit, limit: 1)]
		
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .entry, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .entry))
		XCTAssertTrue(message.isLive(for: .exit))
		
		message.triggerEvent(for: .exit, region: pulaObject, datasource: MobileMessaging.geofencingService!.datasource)
		XCTAssertFalse(message.isLive(for: .exit))
	}
	
	//MARK: - delivery time tests
	
	func testAbsentDeliveryWindow() {
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload, createdDate: Date()) else {
			XCTFail()
			return
		}
		XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
		XCTAssertFalse(message.isNowAppropriateTimeForExitNotification)
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
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			do {
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			// appropriate time, day not set
	//			do {
	//				let timeIntervalString = "1200/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			do {
	//				let timeIntervalString = "2300/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			// appropriate day and time
	//			do {
	//				let timeIntervalString = "1200/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			do {
	//				let timeIntervalString = "2300/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//
	//			// inappropriate day
	//			do {
	//				let timeIntervalString = "1200/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			do {
	//				let timeIntervalString = "2300/1230"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//
	//			// inappropriate time
	//			do {
	//				let timeIntervalString = "0000/1215"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//
	//			do {
	//				let timeIntervalString = "1230/2335"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//
	//			// inappropriate day and time
	//			do {
	//				let timeIntervalString = "0000/1215"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//			do {
	//				let timeIntervalString = "1230/2335"
	//				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [makeNonExpiringRegion(modernPulaDict), makeNonExpiringRegion(modernZagrebDict)])
	//				guard let message = MMGeoMessage(payload: payload, createdDate: NSDate()) else {
	//					XCTFail()
	//					return
	//				}
	//				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
	//			}
	//
	//		}
	//	}
	
	func testTimeWindowDictRepresentations() {
		let timeIntervalString = "0000/1215"
		let friday = "5"
		let apnsPayload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: friday), regions: [modernPulaDict, modernZagrebDict])
		
		let dictRepresentation = MMGeoMessage(payload: apnsPayload, createdDate: Date())!.originalPayload
		XCTAssertNotNil(MMGeoMessage(payload: dictRepresentation, createdDate: Date()))
		XCTAssertTrue((dictRepresentation as NSDictionary).isEqual(apnsPayload as NSDictionary))
	}
}
