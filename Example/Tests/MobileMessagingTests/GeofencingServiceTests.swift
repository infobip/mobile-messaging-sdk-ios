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

let expectedDateString = "2016-08-06T12:20:16+03:00"
let expectedMillisNumber = NSNumber(longLong: 1470475216000)
let expectedMillisString = "1470475216000"

class GeofencingServiceTests: MMTestCase {
	var expectedDate: NSDate {
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
	
	let zagreb: [String: AnyObject] = [
		MMRegionDataKeys.ExpiryMillis.rawValue: expectedMillisNumber,
		MMRegionDataKeys.ExpiryDate.rawValue: expectedDateString,
		MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
		MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
		MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
		MMRegionDataKeys.Radius.rawValue: 9492,
		MMRegionDataKeys.Title.rawValue: "Zagreb"
	]
	
	let pula: [String: AnyObject] = [
		MMRegionDataKeys.ExpiryMillis.rawValue: expectedMillisNumber,
		MMRegionDataKeys.ExpiryDate.rawValue: expectedDateString,
		MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
		MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
		MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
		MMRegionDataKeys.Radius.rawValue: 5257,
		MMRegionDataKeys.Title.rawValue: "Pula"
	]
	
	var internalData: [String: AnyObject] {
		return [
			MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
			MMAPIKeys.kMessageType: MMAPIKeys.kGeo,
			MMAPIKeys.kGeo: [zagreb, pula]
		]
	}
	
	var apnsPayload: [String: AnyObject] {
		return [
			"messageId": "123",
			"aps": [
				"content-available": 1
			],
			MMAPIKeys.kInternalData: internalData
		]
	}
	
	let oldZagreb: [String: AnyObject] = [
		MMRegionDataKeys.ExpiryMillis.rawValue: expectedMillisNumber,
		MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
		MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
		MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
		MMRegionDataKeys.Radius.rawValue: 9492,
		MMRegionDataKeys.Title.rawValue: "Zagreb"
	]
	
	let oldPula: [String: AnyObject] = [
		MMRegionDataKeys.ExpiryMillis.rawValue: expectedMillisNumber,
		MMRegionDataKeys.Identifier.rawValue: "A277A2A0D0612AFB652E9D2D80E02BF2",
		MMRegionDataKeys.Latitude.rawValue: 44.86803631018752,
		MMRegionDataKeys.Longitude.rawValue: 13.84586334228516,
		MMRegionDataKeys.Radius.rawValue: 5257,
		MMRegionDataKeys.Title.rawValue: "Pula"
	]
	
	var oldInternalData: [String: AnyObject] {
		return [
			MMAPIKeys.kSilent: [MMAPIKeys.kBody: "campaign text"],
			MMAPIKeys.kMessageType: MMAPIKeys.kGeo,
			MMAPIKeys.kGeo: [oldZagreb, oldPula]
		]
	}
	
	var oldapnsPayload: [String: AnyObject] {
		return [
			"messageId": "123",
			"aps": [
				"content-available": 1
			],
			MMAPIKeys.kInternalData: oldInternalData
		]
	}
	
	func testCampaignAPNSConstructors() {
		if let message = MMMessage(payload: apnsPayload), let campaign = MMCampaign(message: message) {
			
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = zagreb[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, zagreb[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, zagreb[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, zagreb[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, zagreb[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = pula[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, pula[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, pula[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, pula[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, pula[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertTrue(pulaObject.isExpired)
		} else {
			XCTFail()
		}
	}
	
	func testOldCampaignAPNSConstructors() {
		if let message = MMMessage(payload: oldapnsPayload), let campaign = MMCampaign(message: message) {
			
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = zagreb[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, zagreb[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, zagreb[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, zagreb[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, zagreb[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = pula[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, pula[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, pula[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, pula[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, pula[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertTrue(pulaObject.isExpired)
		} else {
			XCTFail()
		}
	}
	
	let jsonStr =
		"{" +
			"\"aps\": { \"content-available\": 1}," +
			"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
			"\"internalData\": {" +
			"\"silent\": { \"body\": \"campaign text\"}," +
			"\"geo\": [" +
			"{" +
			"\"expiryTime\": \""+expectedDateString+"\"," +
			"\"expiry\": "+expectedMillisString+"," +
			"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
			"\"latitude\": 45.80869126677998," +
			"\"longitude\": 15.97206115722656," +
			"\"radiusInMeters\": 9492," +
			"\"title\": \"Zagreb\"" +
			"}," +
			"{" +
			"\"expiryTime\": \""+expectedDateString+"\"," +
			"\"expiry\": "+expectedMillisString+"," +
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
			"\"expiry\": "+expectedMillisString+"," +
			"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
			"\"latitude\": 45.80869126677998," +
			"\"longitude\": 15.97206115722656," +
			"\"radiusInMeters\": 9492," +
			"\"title\": \"Zagreb\"" +
			"}," +
			"{" +
			"\"expiry\": "+expectedMillisString+"," +
			"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
			"\"latitude\": 44.86803631018752," +
			"\"longitude\": 13.84586334228516," +
			"\"radiusInMeters\": 5257," +
			"\"title\": \"Pula\"" +
			"}" +
			"]" +
			"}" +
	"}"
	
	func testCampaignJSONConstructors() {
		let json = JSON.parse(jsonStr)
		
		if let message = MMMessage(json: json), let campaign = MMCampaign(message: message) {
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertTrue(pulaObject.isExpired)
			
		} else {
			XCTFail()
		}
	}
	
	func testOldCampaignJSONConstructors() {
		let json = JSON.parse(oldjsonStr)
		
		if let message = MMMessage(json: json), let campaign = MMCampaign(message: message) {
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryDate, expectedDate)
			XCTAssertNotEqual(zagrebObject.expiryDate, notExpectedDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryDate, expectedDate)
			XCTAssertNotEqual(pulaObject.expiryDate, notExpectedDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqualWithAccuracy(pulaObject.center.latitude, 44.86803631018752, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(pulaObject.center.longitude, 13.84586334228516, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, 5257)
			XCTAssertEqual(pulaObject.title, "Pula")
			XCTAssertTrue(pulaObject.isExpired)
			
		} else {
			XCTFail()
		}
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: pula)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: zagreb)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: pula))
		XCTAssertNotNil(MMRegion(dictRepresentation: zagreb))
	}
	
	func testOldDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldPula)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: oldZagreb)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: pula))
		XCTAssertNotNil(MMRegion(dictRepresentation: zagreb))
	}
	
	func testThatNullRadiusRegionNotCreating() {
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 0, title: "region", expiryDateString: ""))
	}
}
