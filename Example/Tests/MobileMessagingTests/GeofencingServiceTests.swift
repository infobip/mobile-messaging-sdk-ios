//
//  GeofencingServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/08/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import CoreLocation
import SwiftyJSON
@testable import MobileMessaging

class GeofencingServiceTests: MMTestCase {
	let zagreb: [String: AnyObject] = [
		MMRegionDataKeys.Expiry.rawValue: NSTimeInterval(1470438000000.0),
		MMRegionDataKeys.Identifier.rawValue: "6713245DA3638FDECFE448C550AD7681",
		MMRegionDataKeys.Latitude.rawValue: 45.80869126677998,
		MMRegionDataKeys.Longitude.rawValue: 15.97206115722656,
		MMRegionDataKeys.Radius.rawValue: 9492,
		MMRegionDataKeys.Title.rawValue: "Zagreb"
	]
	let pula: [String: AnyObject] = [
		MMRegionDataKeys.Expiry.rawValue: NSTimeInterval(1470438000000.0),
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
	
	override func setUp() {
		super.setUp()
		
	}
	
	override func tearDown() {
		
		super.tearDown()
	}
	
	func testCampaignAPNSConstructors() {
		if let message = MMMessage(payload: apnsPayload), let campaign = MMCampaign(message: message) {
			
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			
			let zagrebId = zagreb[MMRegionDataKeys.Identifier.rawValue] as! String
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryms, zagreb[MMRegionDataKeys.Expiry.rawValue] as? NSTimeInterval)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, zagreb[MMRegionDataKeys.Latitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, zagreb[MMRegionDataKeys.Longitude.rawValue] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, zagreb[MMRegionDataKeys.Radius.rawValue] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, zagreb[MMRegionDataKeys.Title.rawValue] as? String)
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = pula[MMRegionDataKeys.Identifier.rawValue] as! String
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryms, pula[MMRegionDataKeys.Expiry.rawValue] as? NSTimeInterval)
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
	
// Freddy overflows while parsing big integers on 32bit devices.
// It should fallback to Double in such cases, but it falls to String by default. It is weird.
// The following test case demonstrates a workaround to force Freddy to fallback to Double if Int is overflown.
// Another solution is to `try` parse retrieve an Int from JSON object, `catch` the possible error, then try to retrieve a string
// https://github.com/bignerdranch/Freddy/issues/76
//	func testParsingOutALargeNumberEspeciallyOn32BitPlatforms() {
//		let val = 1466719200000.0
//		let str = "{\"startDate\": 1466719200000}"
//		let data = str.dataUsingEncoding(NSUTF8StringEncoding)!
//		let json = try? (sizeof(Int) == sizeof(Int64)) ? JSON(data: data) : JSON(data: data, usingParser: NSJSONSerialization.self)
//		XCTAssertEqual(try? json!.double("startDate"), val)
//	}
	
	func testCampaignJSONConstructors() {
		let jsonStr =
		"{" +
			"\"aps\": { \"content-available\": 1}," +
			"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
			"\"internalData\": {" +
			"\"silent\": { \"body\": \"campaign text\"}," +
			"\"geo\": [" +
			"{" +
			"\"expiry\": 1470438000000," +
			"\"id\": \"6713245DA3638FDECFE448C550AD7681\"," +
			"\"latitude\": 45.80869126677998," +
			"\"longitude\": 15.97206115722656," +
			"\"radiusInMeters\": 9492," +
			"\"title\": \"Zagreb\"" +
			"}," +
			"{" +
			"\"expiry\": 1470438000000," +
			"\"id\": \"A277A2A0D0612AFB652E9D2D80E02BF2\"," +
			"\"latitude\": 44.86803631018752," +
			"\"longitude\": 13.84586334228516," +
			"\"radiusInMeters\": 5257," +
			"\"title\": \"Pula\"" +
			"}" +
			"]" +
			"}" +
		"}"
		
		let json = JSON.parse(jsonStr)
		
		if let message = MMMessage(json: json), let campaign = MMCampaign(message: message) {
			var regionsDict = [String: MMRegion]()
			for region in campaign.regions {
				regionsDict[region.identifier] = region
			}
			let zagrebId = "6713245DA3638FDECFE448C550AD7681"
			let zagrebObject = regionsDict[zagrebId]!
			XCTAssertEqual(zagrebObject.expiryms, NSTimeInterval(1470438000000.0))
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqualWithAccuracy(zagrebObject.center.latitude, 45.80869126677998, accuracy: 0.000000000001)
			XCTAssertEqualWithAccuracy(zagrebObject.center.longitude, 15.97206115722656, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, 9492)
			XCTAssertEqual(zagrebObject.title, "Zagreb")
			XCTAssertTrue(zagrebObject.isExpired)
			
			let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
			let pulaObject = regionsDict[pulaId]!
			XCTAssertEqual(pulaObject.expiryms, NSTimeInterval(1470438000000.0))
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
	
	func testThatNullRadiusRegionNotCreating() {
		XCTAssertNil(MMRegion(identifier: "id1", center: CLLocationCoordinate2D(latitude: 1, longitude: 1), radius: 0, title: "region", expiryms: 1))
	}
}
