//
//  GeofencingServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/08/16.
//

import XCTest
import CoreLocation
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

class LocationManagerStub: CLLocationManager {
	var locationStub: CLLocation?
	var monitoredRegionsArray = [CLRegion]()
	
	init(locationStub: CLLocation? = nil) {
		self.locationStub = locationStub
		super.init()
	}
	
	override var monitoredRegions: Set<CLRegion> {
		get { return Set(monitoredRegionsArray)}
		set {}
	}
	
	override var location: CLLocation? {
		return locationStub ?? super.location
	}
	override func startMonitoring(for region: CLRegion) {
		monitoredRegionsArray.append(region)
	}
	
	override func stopMonitoring(for region: CLRegion) {
		if let index = monitoredRegionsArray.index(of: region) {
			monitoredRegionsArray.remove(at: index)
		}
	}
}

class GeofencingServiceAlwaysRunningStub: GeofencingService {
	init(mmContext: MobileMessaging, locationManagerStub: LocationManagerStub = LocationManagerStub()) {
		self.stubbedLocationManager = locationManagerStub
		super.init(mmContext: mmContext)
	}
	
	var didEnterRegionCallback: ((MMRegion) -> Void)?
	override var isRunning: Bool {
		set {}
		get { return true }
	}
	
	override var locationManager: CLLocationManager! {
		set {}
		get {
			return stubbedLocationManager
		}
	}
	
	var stubbedLocationManager: LocationManagerStub
	
	override func authorizeService(kind: LocationServiceKind, usage: LocationServiceUsage, completion: @escaping (GeofencingCapabilityStatus) -> Void) {
		completion(.authorized)
	}
	
	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}
	
	override func onEnter(datasourceRegion: MMRegion, completion: (() -> Void)?) {
		self.didEnterRegionCallback?(datasourceRegion)
	}
	
	override func stop(_ completion: ((Bool) -> Void)?) {
		eventsHandlingQueue.cancelAllOperations()
		self.isRunning = false
		stubbedLocationManager.monitoredRegionsArray = [CLRegion]()
	}
	
	override public class var currentCapabilityStatus: GeofencingCapabilityStatus {
		return GeofencingCapabilityStatus.authorized
	}
}

class GeofencingServiceDisabledStub: GeofencingService {
	init(mmContext: MobileMessaging, locationManagerStub: LocationManagerStub = LocationManagerStub()) {
		self.locationManagerStub = locationManagerStub
		super.init(mmContext: mmContext)
	}
	
	var didEnterRegionCallback: ((MMRegion) -> Void)?
	override var isRunning: Bool {
		set {}
		get { return false }
	}
	
	override var locationManager: CLLocationManager! {
		set {}
		get {
			return locationManagerStub
		}
	}
	
	var locationManagerStub: LocationManagerStub
	
	override func authorizeService(kind: LocationServiceKind, usage: LocationServiceUsage, completion: @escaping (GeofencingCapabilityStatus) -> Void) {
		completion(.denied)
	}
	
	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}
	
	override func onEnter(datasourceRegion: MMRegion, completion: (() -> Void)?) {
		self.didEnterRegionCallback?(datasourceRegion)
	}
	
	override func stop(_ completion: ((Bool) -> Void)?) {
		eventsHandlingQueue.cancelAllOperations()
		self.isRunning = false
		locationManagerStub.monitoredRegionsArray = [CLRegion]()
	}
	
	override public class var currentCapabilityStatus: GeofencingCapabilityStatus {
		return GeofencingCapabilityStatus.denied
	}
}

let expectedCampaignId = "campaign 1"
let expectedMessageId = "message 1"
let expectedCampaignText = "campaign text"
let expectedSound = "default"

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

func baseAPNSDict(messageId: String = expectedMessageId) -> APNSPayload {
	return
		[
			APNSPayloadKeys.messageId: messageId,
			APNSPayloadKeys.aps: [
				APNSPayloadKeys.contentAvailable: 1
			]
	]
}

let zagrebId = "6713245DA3638FDECFE448C550AD7681"
let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"


// modern:
let modernZagrebDict: APNSPayload = [
	RegionDataKeys.identifier: zagrebId,
	RegionDataKeys.latitude: 45.80869126677998,
	RegionDataKeys.longitude: 15.97206115722656,
	RegionDataKeys.radius: 9492.0,
	RegionDataKeys.title: "Zagreb"
]

let modernPulaDict: APNSPayload = [
	RegionDataKeys.identifier: pulaId,
	RegionDataKeys.latitude: 44.86803631018752,
	RegionDataKeys.longitude: 13.84586334228516,
	RegionDataKeys.radius: 5257.0,
	RegionDataKeys.title: "Pula"
]

var modernInternalDataWithZagrebPulaDict: APNSPayload {
	var result = makeBaseInternalDataDict(campaignId: expectedCampaignId)
	result[InternalDataKeys.geo] = [modernZagrebDict, modernPulaDict]
	return result
}

var modernAPNSPayloadZagrebPulaDict: APNSPayload {
	return (baseAPNSDict() + [APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
}

// jsons
let jsonStr =
	"{" +
		"\"aps\": { \"content-available\": 1}," +
		"\"messageId\": \"lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=\"," +
		"\"internalData\": {" +
			"\"campaignId\": \"\(expectedCampaignId)\"," +
			"\"silent\": {" +
                "\"body\": \"\(expectedCampaignText)\"," +
                "\"sound\": \"\(expectedSound)\"" +
            "}," +
			"\"startTime\": \"\(expectedStartDateString)\"," +
			"\"expiryTime\": \"\(expectedExpiryDateString)\"," +
			"\"geo\": [" +
				"{" +
					"\"id\": \"\(zagrebId)\"," +
					"\"latitude\": 45.80869126677998," +
					"\"longitude\": 15.97206115722656," +
					"\"radiusInMeters\": 9492.0," +
					"\"title\": \"Zagreb\"" +
				"}," +
				"{" +
					"\"id\": \"\(pulaId)\"," +
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
			"\"campaignId\": \"\(expectedCampaignId)\"," +
			"\"silent\": {" +
                "\"body\": \"\(expectedCampaignText)\"," +
                "\"sound\": \"\(expectedSound)\"" +
            "}," +
			"\"expiryTime\": \""+expectedExpiryDateString+"\"," +
			"\"geo\": [" +
				"{" +
					"\"id\": \"\(zagrebId)\"," +
					"\"latitude\": 45.80869126677998," +
					"\"longitude\": 15.97206115722656," +
					"\"radiusInMeters\": 9492.0," +
					"\"title\": \"Zagreb\"" +
				"}," +
				"{" +
					"\"id\": \"\(pulaId)\"," +
					"\"latitude\": 44.86803631018752," +
					"\"longitude\": 13.84586334228516," +
					"\"radiusInMeters\": 5257.0," +
					"\"title\": \"Pula\"" +
				"}" +
			"]" +
		"}" +
"}"

let suspendedCampaignId = "suspendedCampaignId"
let finishedCampaignId = "finishedCampaignId"

func makeBaseInternalDataDict(campaignId: String) -> APNSPayload {
	return
		[
			CampaignDataKeys.campaignId: campaignId,
			CampaignDataKeys.startDate: expectedStartDateString,
			CampaignDataKeys.expiryDate: expectedExpiryDateString,
			InternalDataKeys.silent: [APNSPayloadKeys.body: expectedCampaignText, APNSPayloadKeys.sound: expectedSound],
			InternalDataKeys.messageType: InternalDataKeys.messageTypeGeo
	]
}

func makeApnsPayloadWithoutRegionsDataDict(campaignId: String, messageId: String) -> APNSPayload {
	return (baseAPNSDict(messageId: messageId) + [APNSPayloadKeys.internalData: makeBaseInternalDataDict(campaignId: campaignId)])!
}

func makeApnsPayload(withEvents events: [APNSPayload]?, deliveryTime: APNSPayload?, regions: [APNSPayload], campaignId: String = expectedCampaignId, messageId: String = expectedMessageId) -> APNSPayload {
	var result = makeApnsPayloadWithoutRegionsDataDict(campaignId: campaignId, messageId: messageId)
	var internalData = result[APNSPayloadKeys.internalData] as! APNSPayload
	internalData[InternalDataKeys.geo] = regions
	internalData[InternalDataKeys.event] = events ?? [defaultEvent]
	internalData[InternalDataKeys.deliveryTime] = deliveryTime
	let distantFutureDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date.distantFuture)
	internalData[CampaignDataKeys.expiryDate] = distantFutureDateString
	result[APNSPayloadKeys.internalData] = internalData
	return result
}

func makeEventDict(ofType type: RegionEventType, limit: Int, timeout: Int? = nil) -> APNSPayload {
	var result: APNSPayload = [RegionEventDataKeys.eventType: type.rawValue,
	                                   RegionEventDataKeys.eventLimit: limit]
	result[RegionEventDataKeys.eventTimeout] = timeout
	return result
}

func makeDeliveryTimeDict(withTimeIntervalString timeInterval: String? = nil, daysString days: String? = nil) -> APNSPayload? {
	var result = APNSPayload()
	result[RegionDeliveryTimeKeys.timeInterval] = timeInterval
	result[RegionDeliveryTimeKeys.days] = days
	return result.isEmpty ? nil : result
}

var defaultEvent = ["limit": 1, "rate": 0, "timeoutInMinutes": 0, "type": "entry"] as APNSPayload


class GeofencingServiceTests: MMTestCase {
	
	func testRealSignalingPayloadParsing() {
		
		let p: APNSPayload =
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
		
		XCTAssertNotNil(MMGeoMessage(payload: p))
		
	}
	
	func testThatTwoSequentalCampaignsAppearTwice() {
		weak var expectationCampaign = self.expectation(description: "")
		GeofencingService.currentDate = expectedStartDate
		var counter = 0
		let zagreb = CLLocation(latitude: 45.80869126677998, longitude: 15.97206115722656)
		let geoStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance, locationManagerStub: LocationManagerStub(locationStub: zagreb))
		geoStub.didEnterRegionCallback = { region in
			counter += 1
			if counter == 2 {
				expectationCampaign?.fulfill()
			}
		}
		GeofencingService.sharedInstance = geoStub
		GeofencingService.sharedInstance!.start()
		
		
		let m1 = (baseAPNSDict(messageId: "m1") + [APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
		self.mobileMessagingInstance.didReceiveRemoteNotification(m1,  completion: { _ in
		})
		
		let m2 = (baseAPNSDict(messageId: "m2") + [APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
		self.mobileMessagingInstance.didReceiveRemoteNotification(m2,  completion: { _ in
		})
		
		self.waitForExpectations(timeout: 5, handler: { _ in
		})
	}
	
	func testThatGeoPushIsPassedToTheGeoService() {
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		weak var expectation = self.expectation(description: "Check finished")
		
		self.mobileMessagingInstance.didReceiveRemoteNotification(modernAPNSPayloadZagrebPulaDict,  completion: { _ in
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
		var apnsPayload = modernAPNSPayloadZagrebPulaDict
		var internalData = apnsPayload[APNSPayloadKeys.internalData] as! [String: AnyObject]
		internalData[CampaignDataKeys.startDate] = nil
		apnsPayload[APNSPayloadKeys.internalData] = internalData
		if let message = MMGeoMessage(payload: apnsPayload) {
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.startTime, Date(timeIntervalSinceReferenceDate: 0))
			XCTAssertEqual(message.startTime, Date(timeIntervalSinceReferenceDate: 0))
		} else {
			XCTFail()
		}
	}
	
	func testCampaignAPNSConstructors() {
		let apnsPayload = modernAPNSPayloadZagrebPulaDict
		
		if let message = MMGeoMessage(payload: apnsPayload) {
			
			let zagrebId = modernZagrebDict[RegionDataKeys.identifier] as! String
			let zagrebObject = message.regions.findZagreb
			XCTAssertEqual(zagrebObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(zagrebObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(zagrebObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(zagrebObject.identifier, zagrebId)
			XCTAssertEqual(zagrebObject.center.latitude, modernZagrebDict[RegionDataKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.center.longitude, modernZagrebDict[RegionDataKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(zagrebObject.radius, modernZagrebDict[RegionDataKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(zagrebObject.title, modernZagrebDict[RegionDataKeys.title] as? String)
			XCTAssertFalse(zagrebObject.message!.isNotExpired)
			
			let pulaId = modernPulaDict[RegionDataKeys.identifier] as! String
			let pulaObject = message.regions.findPula
			XCTAssertEqual(pulaObject.message!.expiryTime, expectedExpiryDate)
			XCTAssertNotEqual(pulaObject.message!.expiryTime, notExpectedDate)
			XCTAssertEqual(pulaObject.message!.startTime, expectedStartDate)
			XCTAssertEqual(pulaObject.identifier, pulaId)
			XCTAssertEqual(pulaObject.center.latitude, modernPulaDict[RegionDataKeys.latitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.center.longitude, modernPulaDict[RegionDataKeys.longitude] as! Double, accuracy: 0.000000000001)
			XCTAssertEqual(pulaObject.radius, modernPulaDict[RegionDataKeys.radius] as? CLLocationDistance)
			XCTAssertEqual(pulaObject.title, modernPulaDict[RegionDataKeys.title] as? String)
			XCTAssertFalse(pulaObject.message!.isNotExpired)
		} else {
			XCTFail()
		}
	}
	
	func testCampaignJSONConstructors() {
		let json = JSON.parse(jsonStr)
		
		if let message = MMGeoMessage(json: json) {
			
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
	}
	
	func testCampaignJSONConstructorsWithoutStartTime() {
		let json = JSON.parse(jsonStrWithoutStartTime)
		
		if let message = MMGeoMessage(json: json) {
			
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
	}
	
	func testDictRepresentations() {
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation)!.dictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernPulaDict as! DictionaryRepresentation))
		XCTAssertNotNil(MMRegion(dictRepresentation: modernZagrebDict as! DictionaryRepresentation))
	}
	
	//MARK: - Events tests
	func testDefaultEventsSettings() {
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload) else
		{
			XCTFail()
			return
		}
		
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertFalse(message.isLiveNow(for: .exit))
		
		var sentSdkMessageId: String!
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
		                                                                                  performRequestCompanionBlock:
		{ r in
				
			if let geoEventReportRequest = r as? GeoEventReportingRequest {
				if  let body = geoEventReportRequest.body,
					let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
				{
					sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
				}
			}

		}, completionCompanionBlock: { _ in
			
		}, responseSubstitution: { r -> JSON? in
			let jsonStr  =
				"{" +
					"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
					"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
					"}" +
				"}"
			let result = JSON.parse(jsonStr)
			return result
		})
		
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				report1?.fulfill()
		
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				
				XCTAssertNil(msg)
			}
			
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				report2?.fulfill()
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				
				XCTAssertNil(msg)
			}
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testOnlyOneEventType() {
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .exit, limit: 1, timeout: 0)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		XCTAssertFalse(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		var sentSdkMessageId: String!
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance, performRequestCompanionBlock:
			{ r in
				
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
					}
				}
				
		}, completionCompanionBlock:
			{ _ in
				
		}, responseSubstitution:
			{ r -> JSON? in
				let jsonStr  =
					"{" +
						"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
						"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
						"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
						"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
						"}" +
				"}"
				let result = JSON.parse(jsonStr)
				return result
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
		
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				report1?.fulfill()
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
			}
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				report2?.fulfill()
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
			}
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}

	
	func testEventsOccuring() {
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		weak var report3 = expectation(description: "report3")
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins),
		              makeEventDict(ofType: .exit, limit: 2, timeout: timeoutInMins)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		let zagrebObject = message.regions.findZagreb
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		var sentSdkMessageId: String!
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
		                                                                                  performRequestCompanionBlock:
		{ r in
				
			if let geoEventReportRequest = r as? GeoEventReportingRequest {
				if  let body = geoEventReportRequest.body,
					let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
				{
					sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
				}
			}
				
		}, completionCompanionBlock: { _ in
			
		}, responseSubstitution: { r -> JSON? in
			let jsonStr  =
				"{" +
					"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
					"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
					"}" +
			"}"
			let result = JSON.parse(jsonStr)
			return result
		})
		
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			
			let group = DispatchGroup()
			group.enter()
			group.enter()
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertTrue(msg!.isLiveNow(for: .exit))
				
				report1?.fulfill()
				group.leave()
			}
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertFalse(msg!.isLiveNow(for: .exit))
				
				report2?.fulfill()
				group.leave()
			}
			
			
			group.notify(queue: DispatchQueue.main) {
			
				// move to the future
				GeofencingService.currentDate = Date(timeIntervalSinceNow: Double(timeoutInMins) * Double(60))
				
				// so that they look alive again
				XCTAssertTrue(message.isLiveNow(for: .entry))
				XCTAssertTrue(message.isLiveNow(for: .exit))
				
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: zagrebObject.identifier, geoMessage: message) { state in
					XCTAssertEqual(CampaignState.Active, state)
				
					
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
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMGeoRemoteAPIAlwaysSucceeding(mmContext: self.mobileMessagingInstance)

		let events = [makeEventDict(ofType: .entry, limit: 0, timeout: 0),
		              makeEventDict(ofType: .exit, limit: 0, timeout: 0)]
		
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload) else {
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
				XCTAssertEqual(CampaignState.Active, state)
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
		
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .entry, limit: 1),
		              makeEventDict(ofType: .exit, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		XCTAssertTrue(message.isLiveNow(for: .entry))
		XCTAssertTrue(message.isLiveNow(for: .exit))
		
		var sentSdkMessageId: String!
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
		                                                                                  performRequestCompanionBlock:
			{ r in
				
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
					}
				}
				
		}, completionCompanionBlock: { _ in
			
		}, responseSubstitution: { r -> JSON? in
			let jsonStr  =
				"{" +
					"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
					"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
					"}" +
			"}"
			let result = JSON.parse(jsonStr)
			return result
		})
		
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertFalse(msg!.isLiveNow(for: .entry))
				XCTAssertTrue(msg!.isLiveNow(for: .exit))
				report1?.fulfill()
			}
			
			MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				
				let msg = MobileMessaging.geofencingService!.datasource.messages.first
				XCTAssertNil(msg)
				report2?.fulfill()
			}
		})
		waitForExpectations(timeout: 20, handler: nil)
	}
	
	func testReportSentOnlyOnce() {
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		let events = [makeEventDict(ofType: .entry, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = geofencingServiceQueueMock()
		mobileMessagingInstance.didReceiveRemoteNotification(payload) { _ in
			let validEntryRegions = GeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)
			
			MobileMessaging.geofencingService?.report(on: .entry, forRegionId: pulaId, geoMessage: message, completion: { (s) in
				report1?.fulfill()
			})
			
			MobileMessaging.geofencingService?.syncWithServer(completion: { (result) in
				if let result = result {
					switch result {
					case .Cancel: report2?.fulfill()
					default: XCTFail()
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
	
	func geofencingServiceQueueMock() -> MMRemoteAPIMock {
		var sentSdkMessageId: String = ""
		return MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
		                       performRequestCompanionBlock:
			{ r in
				
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
					}
				}
				
		}, completionCompanionBlock: { _ in
			
		}, responseSubstitution: { r -> JSON? in
			let jsonStr  =
				"{" +
					"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
					"\"\(sentSdkMessageId)\": \"ipcoremessageid\"" +
					"}" +
			"}"
			let result = JSON.parse(jsonStr)
			return result
		})
	}
	
	//MARK: - delivery time tests
	
	func testAbsentDeliveryWindow() {
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
		XCTAssertFalse(message.isNowAppropriateTimeForExitNotification)
	}
	

	func testParticularDeliveryWindows() {

		let testDate: Date = {
			let comps = NSDateComponents()
			comps.year = 2016
			comps.month = 10
			comps.day = 9
			comps.hour = 12
			comps.minute = 20
			comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
			return comps.date!
		}()

		let sunday = "7"
		let thursdaySunday = "4,7"
		let monday = "1"

		timeTravel(to: testDate) {
			// appropriate day, time not set
			do {
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: nil, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			// appropriate time, day not set
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: nil), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			// appropriate day and time
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: thursdaySunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertTrue(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate day
			do {
				let timeIntervalString = "1200/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "2300/1230"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate time
			do {
				let timeIntervalString = "0000/1215"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			do {
				let timeIntervalString = "1230/2335"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: sunday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

			// inappropriate day and time
			do {
				let timeIntervalString = "0000/1215"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}
			do {
				let timeIntervalString = "1230/2335"
				let payload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: monday), regions: [modernPulaDict, modernZagrebDict])
				guard let message = MMGeoMessage(payload: payload) else {
					XCTFail()
					return
				}
				XCTAssertFalse(message.isNowAppropriateTimeForEntryNotification)
			}

		}
	}
	
	func testTimeWindowDictRepresentations() {
		let timeIntervalString = "0000/1215"
		let friday = "5"
		let apnsPayload = makeApnsPayload(withEvents: nil, deliveryTime: makeDeliveryTimeDict(withTimeIntervalString: timeIntervalString, daysString: friday), regions: [modernPulaDict, modernZagrebDict])
		
		let dictRepresentation = MMGeoMessage(payload: apnsPayload)!.originalPayload
		XCTAssertNotNil(MMGeoMessage(payload: dictRepresentation))
		XCTAssertTrue((dictRepresentation as NSDictionary).isEqual(apnsPayload as NSDictionary))
	}
	
	func testGeoEventsStorageSuccessfullyReported() {
		// triggers 2 events and mocks successfull reportings wich ends up with an empty events storage
		generalTestForPersistingEventReports(with: MMGeoRemoteAPIAlwaysSucceeding(mmContext: self.mobileMessagingInstance), expectedEventsCount: 0)
	}
	
	func testGeoEventsStorageUnsuccessfullyReported() {
		// triggers 2 events and mocks failed reportings wich ends up with an events storage containing 2 records
		generalTestForPersistingEventReports(with: MMRemoteAPIAlwaysFailing(mmContext: self.mobileMessagingInstance), expectedEventsCount: 2)
	}

	func testThatReportsAreBeingSentToTheServerWithCorrectData() {
		
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload) else
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
		let remoteAPIMock = MMGeoRemoteAPIAlwaysSucceeding(mmContext: self.mobileMessagingInstance) { (request) in
			if let request = request as? GeoEventReportingRequest {
				if let report = request.eventsDataList.first {
					sentCampaignIds.insert(report.campaignId)
					sentGeoAreaIds.insert(report.geoAreaId)
					sentEventTypes.insert(report.eventType.rawValue)
					sentMessageIds.insert(report.messageId)
				}
				
                let geoMessage = request.geoMessages.first!
                XCTAssertEqual(geoMessage.campaignId, expectedCampaignId)
                XCTAssertEqual(geoMessage.messageId, expectedMessageId)
                
				reportSentCounter += 1
			} else {
				XCTFail()
			}
			if reportSentCounter == 2 {
				XCTAssertTrue(sentCampaignIds.contains(expectedCampaignId))
				XCTAssertEqual(sentCampaignIds.count, 1)
				
				XCTAssertTrue(sentGeoAreaIds.contains(zagrebId))
				XCTAssertTrue(sentGeoAreaIds.contains(pulaId))
				XCTAssertEqual(sentGeoAreaIds.count, 2)
				
				XCTAssertTrue(sentEventTypes.contains(RegionEventType.entry.rawValue))
				XCTAssertTrue(sentEventTypes.contains(RegionEventType.exit.rawValue))
				XCTAssertEqual(sentEventTypes.count, 2)
				
				print(sentMessageIds)
				XCTAssertTrue(sentMessageIds.contains(expectedMessageId))
				XCTAssertEqual(sentMessageIds.count, 1)
				
				eventReported?.fulfill()
			}
		}
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = remoteAPIMock
		
        self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
            // simulate entry event
            MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
                XCTAssertEqual(CampaignState.Active, state)
                report1?.fulfill()
            }
            MobileMessaging.geofencingService!.report(on: .exit, forRegionId: zagrebObject.identifier, geoMessage: message) { state in
                XCTAssertEqual(CampaignState.Active, state)
                report2?.fulfill()
            }
        })
        
        self.waitForExpectations(timeout: 10, handler: nil)
	}
	
	//MARK: - Private helpers
	private func generalTestForPersistingEventReports(with apiMock: RemoteAPIQueue, expectedEventsCount: Int) {
        
        weak var eventsDatabaseCheck1 = self.expectation(description: "eventsDatabaseCheck1")
        weak var messageReceived = self.expectation(description: "messageReceived")
        
		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict])
		guard let message = MMGeoMessage(payload: payload) else
		{
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
		
		// expect remote api queue called
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = apiMock
		
        self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
    
            messageReceived?.fulfill()
            
            // simulate entry event
            let reportSendingGroup = DispatchGroup()
            reportSendingGroup.enter()
            reportSendingGroup.enter()
			
            MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
                XCTAssertEqual(CampaignState.Active, state)
                reportSendingGroup.leave()
            })
            
            MobileMessaging.geofencingService!.report(on: .exit, forRegionId: pulaObject.identifier, geoMessage: message, completion:  { state in
                XCTAssertEqual(CampaignState.Active, state)
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
	
	func testSuspendedCampaigns() {
		weak var report1 = self.expectation(description: "report1")
        weak var messageReceived = self.expectation(description: "messageReceived")
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPICampaignStatesStub(mobileMessagingContext: mobileMessagingInstance, suspendedCampaignId: suspendedCampaignId, finishedCampaignId: finishedCampaignId)

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict], campaignId: suspendedCampaignId)
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		let pulaObject = message.regions.findPula
        
        self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
            
            messageReceived?.fulfill()
            
            MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
                XCTAssertEqual(CampaignState.Suspended, state)
                report1?.fulfill()
            })
        })
		
		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testFinishedCampaigns() {
		weak var report1 = expectation(description: "report1")
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPICampaignStatesStub(mobileMessagingContext: mobileMessagingInstance, suspendedCampaignId: suspendedCampaignId, finishedCampaignId: finishedCampaignId)

		let payload = makeApnsPayload(withEvents: nil, deliveryTime: nil, regions: [modernPulaDict, modernZagrebDict], campaignId: finishedCampaignId)
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				let pulaObject = message.regions.findPula
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
					
					XCTAssertEqual(CampaignState.Finished, state)
					let ctx = self.storage.mainThreadManagedObjectContext!
					ctx.reset()
					let message = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "campaignId == %@", finishedCampaignId), context: ctx)
					
					XCTAssertEqual(CampaignState.Finished, message?.campaignState)
					report1?.fulfill()
					
				})
			}
		})
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testEventNotOccuredAgaingAfterRestartTheService() {
		weak var messageExp = expectation(description: "messageExp")
		weak var reportExp = expectation(description: "reportExp")
		
		let oldDatasource = MobileMessaging.geofencingService!.datasource
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		
		var sentSdkMessageId: String!
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
		                                                                                  performRequestCompanionBlock:
			{ r in
				
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
					}
				}
				
		}, completionCompanionBlock: { _ in
			
		}, responseSubstitution: { r -> JSON? in
			let jsonStr  =
				"{" +
					"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
					"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
					"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
					"}" +
			"}"
			let result = JSON.parse(jsonStr)
			return result
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			messageExp?.fulfill()

			let pulaObject = message.regions.findPula
			
			XCTAssertTrue(message.isLiveNow(for: .entry))
			
			MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message) { state in
				XCTAssertEqual(CampaignState.Active, state)
				
				//Check that occurence count was saved in DB
				DispatchQueue.main.async {
					MobileMessaging.geofencingService?.datasource = GeofencingDatasource(storage: self.storage)
					XCTAssertFalse(oldDatasource! === MobileMessaging.geofencingService!.datasource)
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
		weak var didEnterRegionExp = expectation(description: "didEnterRegionExp")
		
		var didEnterRegionCount = 0
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payloadOfCampaign1 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId1", messageId: "messageId1")
		let payloadOfCampaign2 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId2", messageId: "messageId2")
		
		guard let message1 = MMGeoMessage(payload: payloadOfCampaign1),
			let message2 = MMGeoMessage(payload: payloadOfCampaign2) else {
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
		
		GeofencingService.sharedInstance = geoServiceStub
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMGeoRemoteAPIAlwaysSucceeding(mmContext: self.mobileMessagingInstance)
		geoServiceStub.stubbedLocationManager.locationStub = CLLocation(latitude: 45.80869126677998, longitude: 15.97206115722656)
		geoServiceStub.add(message: message1)
		geoServiceStub.add(message: message2)
		
		geoServiceStub.locationManager(geoServiceStub.stubbedLocationManager, didEnterRegion: message1.regions.findPula.circularRegion)

		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatRegionsAreNotDuplicatedInTheMonitoredRegions() {
		weak var didEnterRegionExp = expectation(description: "didEnterRegionExp")
		
		var didEnterRegionCount = 0
		let timeoutInMins: Int = 1
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: timeoutInMins)]
		let payloadOfCampaign1 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId1", messageId: "messageId3")
		let payloadOfCampaign2 = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict], campaignId: "campaignId2", messageId: "messageId4")
		
		guard let message1 = MMGeoMessage(payload: payloadOfCampaign1),
			let message2 = MMGeoMessage(payload: payloadOfCampaign2) else {
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
				print("!!! \(monitoredRegionsArray)")
				XCTAssertEqual(monitoredRegionsArray.count, 1)
				didEnterRegionExp?.fulfill()
			}
		}
		
		GeofencingService.sharedInstance = geoServiceStub
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMGeoRemoteAPIAlwaysSucceeding(mmContext: self.mobileMessagingInstance)
		
		geoServiceStub.stubbedLocationManager.locationStub = CLLocation(latitude: pulaObject1.center.latitude, longitude: pulaObject1.center.longitude)
		geoServiceStub.add(message: message1)
		geoServiceStub.add(message: message2)
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatVirtualGeoMessagesCreated() {
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: "none", finishedCampaignId: "none") {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 1, expectedAllMessagesCount: 2)
		})
    }
	
	func testThatVirtualGeoMessageHasGeoAreaData() {
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
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: expectedCampaignId, finishedCampaignId: "none") {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 0, expectedAllMessagesCount: 1)
		})
    }
    
    func testThatVirtualGeoMessagesNotCreatedForFinishedCampaign() {
		weak var e = expectation(description: "test finished")
		testVirtualGeoMessages(suspendedCampaignId: "none", finishedCampaignId: expectedCampaignId) {
			e?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: { er in
			self.checkVirtualGeoMessagesStorageExpectations(expectedVirtualMessagesCount: 0, expectedAllMessagesCount: 1)
		})
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
	
	func testVirtualGeoMessages(suspendedCampaignId: String, finishedCampaignId: String, completion: @escaping () -> Void) {
		
        let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
        let geoSignalingMessagePayload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
        guard let geoSignalingMessage = MMGeoMessage(payload: geoSignalingMessagePayload) else {
            XCTFail()
            return
        }
        let pulaObject = geoSignalingMessage.regions.findPula
        var sentSdkMessageId: String!
        
        mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
        GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
            performRequestCompanionBlock: { (r) in
                
            if let geoEventReportRequest = r as? GeoEventReportingRequest {
                if  let body = geoEventReportRequest.body,
                    let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first,
                    let message = (body[GeoReportingAPIKeys.messages] as? [DictionaryRepresentation])?.first
                {
                    XCTAssertEqual(body[PushRegistration.internalId] as? String, MMTestConstants.kTestCorrectInternalID)
                    XCTAssertEqual(body[PushRegistration.platform] as? String, APIValues.platformType)
                    XCTAssertEqual(report[GeoReportingAPIKeys.campaignId] as? String, expectedCampaignId)
                    XCTAssertEqual(report[GeoReportingAPIKeys.geoAreaId] as? String, pulaObject.identifier)
                    XCTAssertEqual(report[GeoReportingAPIKeys.event] as? String, RegionEventType.entry.rawValue)
                    XCTAssertEqual(report[GeoReportingAPIKeys.messageId] as? String, expectedMessageId)
                    
                    sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String
                    XCTAssertTrue(sentSdkMessageId.mm_isUUID)
                    
                    XCTAssertEqual(message["messageId"] as? String, expectedMessageId)
                    XCTAssertEqual(message["body"] as? String, expectedCampaignText)
                    XCTAssertEqual(message["alert"] as? String, expectedCampaignText)
                    XCTAssertEqual(message["silent"] as? Bool, true)
                    XCTAssertEqual(message["sound"] as? String, expectedSound)
                    XCTAssertNil(message["title"])
                    XCTAssertNil(message["badge"])
                    XCTAssertNil(message["vibrate"])
                    XCTAssertNotNil(message["internalData"])
                }
            }
        },
            completionCompanionBlock: { _ in },
            
            responseSubstitution: { (r) -> JSON? in
                let jsonStr  =
                "{" +
                    "\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
                    "\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
                    "\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
                        "\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
                    "}" +
                "}"
                let result = JSON.parse(jsonStr)
                return result
        })
		
        mobileMessagingInstance.didReceiveRemoteNotification(geoSignalingMessagePayload,  completion: { _ in
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
		weak var notReachableTest = expectation(description: "test finished (w/o internet)")
		weak var reachableTest = expectation(description: "test finished (w/ internet)")
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		var sentSdkMessageId: String!
		let pulaObject = message.regions.findPula
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
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
	
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
			performRequestCompanionBlock: { (r) in
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String // intercepts the sdk generated message id
						XCTAssertTrue(sentSdkMessageId.mm_isUUID)
					}
				}
			},
			
			completionCompanionBlock: { _ in
			
			},
			
			responseSubstitution: { (r) -> JSON? in
				if self.mobileMessagingInstance.reachabilityManager.currentlyReachable() {
					let jsonStr  =
						"{" +
							"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
							"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
							"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
							"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
							"}" +
					"}"
					let result = JSON.parse(jsonStr)
					return result // if the internet is reachable, return a good json response
				} else {
					return nil // if the reachability is lost, it would be an error and nil JSON response, obviously
				}
			}
		)

		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				// at this point there must be no internet:
				self.mobileMessagingInstance.reachabilityManager = MMReachabilityManagerStub(isReachable: false)
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
					
					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
						notReachableTest?.fulfill()
						checkNotReachableExpectations()
						
						// now turn the internet on:
						self.mobileMessagingInstance.reachabilityManager = MMReachabilityManagerStub(isReachable: true)
						
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
	
	
	func testSetSeenForSdkGeneratedMessages() {
		// we expect that none seen status updates will be sent to the server until the real message id is retrieved
		
		weak var notReachableTest = expectation(description: "test finished (w/o internet)")
		weak var seenForSdkGeneratedIdCompleted = expectation(description: "seenForSdkGeneratedIdCompleted")
		weak var seenForRealIdCompleted = expectation(description: "seenForRealIdCompleted")
		let events = [makeEventDict(ofType: .entry, limit: 2, timeout: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload) else {
			XCTFail()
			return
		}
		var sentSdkMessageId: String!
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
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.remoteApiManager.seenStatusQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance, performRequestCompanionBlock: { (r) in
			XCTFail() // the seen must not be sent, there are only sdk generated message ids
		}, completionCompanionBlock: { (r) in
			XCTFail()
		}, responseSubstitution: { (r) -> JSON? in
			XCTFail()
			return nil
		})
		
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = MMRemoteAPIMock(mmContext: self.mobileMessagingInstance,
			performRequestCompanionBlock: { (r) in
				if let geoEventReportRequest = r as? GeoEventReportingRequest {
					if  let body = geoEventReportRequest.body,
						let report = (body[GeoReportingAPIKeys.reports] as? [DictionaryRepresentation])?.first
					{
						sentSdkMessageId = report[GeoReportingAPIKeys.sdkMessageId] as! String // intercepts the sdk generated message id
						XCTAssertTrue(sentSdkMessageId.mm_isUUID)
					}
				}
		},
			
			completionCompanionBlock: { _ in
				
		},
			
			responseSubstitution: { (r) -> JSON? in
				if self.mobileMessagingInstance.reachabilityManager.currentlyReachable() {
					let jsonStr  =
						"{" +
							"\"\(GeoReportingAPIKeys.finishedCampaignIds)\": [\"\(finishedCampaignId)\"]," +
							"\"\(GeoReportingAPIKeys.suspendedCampaignIds)\": [\"\(suspendedCampaignId)\"]," +
							"\"\(GeoReportingAPIKeys.messageIdsMap)\": {" +
							"\"\(sentSdkMessageId!)\": \"ipcoremessageid\"" +
							"}" +
					"}"
					let result = JSON.parse(jsonStr)
					return result // if the internet is reachable, return a good json response
				} else {
					return nil // if the reachability is lost, it would be an error and nil JSON response, obviously
				}
		})
		
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
			//Should be in main because Geofencing service saves data asynchronously in main
			DispatchQueue.main.async {
				// at this point there must be no internet:
				self.mobileMessagingInstance.reachabilityManager = MMReachabilityManagerStub(isReachable: false)
				MobileMessaging.geofencingService!.report(on: .entry, forRegionId: pulaObject.identifier, geoMessage: message, completion: { state in
					
					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
						notReachableTest?.fulfill()

						// now turn the internet on:
						self.mobileMessagingInstance.reachabilityManager = MMReachabilityManagerStub(isReachable: true)
						
						// now lets try to set seen on the sdk generated message id
						self.mobileMessagingInstance.setSeen([sentSdkMessageId], completion: { (seenResult) in
							checkSeenPersistanceExpectations()
							seenForSdkGeneratedIdCompleted?.fulfill()
							
							self.mobileMessagingInstance.remoteApiManager.seenStatusQueue = RemoteAPILocalMocks(mmContext: self.mobileMessagingInstance, baseURLString: MMTestConstants.kTestBaseURLString, appCode: "_")
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
	
	func testHandlingOfFetchedGeoPayload() {
		let regionId = "7867EB6623F628AE2EC71EF3135A2B29"
		let jsonFromPushUp = "{\"messageId\": \"rCpFVUbewlXjnHGu4ZmnuDQTEtvX7moFrWM80jYMhEE=\",\"customPayload\": {},\"internalData\": {\"geo\": [{\"id\": \"\(regionId)\",\"title\": \"SPB Office\",\"radiusInMeters\": 102,\"latitude\": 59.96102588813523,\"longitude\": 30.304096912685168,\"favorite\": false}],\"messageType\": \"geo\",\"campaignId\": \"770789\",\"expiryTime\": \"2017-06-29T10:15:00+00:00\",\"silent\": {\"body\": \"fetching geo test 111\",\"sound\": \"default\"}},\"aps\": {\"alert\": {\"body\": \"fetching geo test 111\"}},\"silent\": true}"
		
		
		guard let payload = JSON.parse(jsonFromPushUp).dictionaryObject,
			let message = MTMessage(payload: payload),
			let geoMessage = MMGeoMessage(payload: payload) else {
				XCTFail()
				return
		}
		
		weak var report1 = expectation(description: "report1")
		weak var report2 = expectation(description: "report2")
		
		MobileMessaging.messageHandling = MessageHandlingMock(localNotificationShownBlock: { _m in
			XCTAssertEqual(_m.text, message.text)
			report2?.fulfill()
		})
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		GeofencingService.sharedInstance = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance)
		GeofencingService.sharedInstance!.start()
		GeofencingService.sharedInstance!.geofencingServiceQueue = geofencingServiceQueueMock()
		mobileMessagingInstance.didReceiveRemoteNotification(payload) { _ in
			MobileMessaging.geofencingService?.report(on: .entry, forRegionId: regionId, geoMessage: geoMessage, completion: { result in
				report1?.fulfill()
			})
		}
		
		waitForExpectations(timeout: 30) { error in
			if error != nil { XCTFail() }
			if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(events.count, 0)
			}
		}
	}
}

final class MMRemoteAPICampaignStatesStub : MMRemoteAPIMock {
	
	convenience init(mobileMessagingContext: MobileMessaging, suspendedCampaignId: String, finishedCampaignId: String) {
		
		
		self.init(baseURLString: "stub", appCode: "stub", mmContext: mobileMessagingContext, performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: { request -> JSON? in
			
			if let request = request as? GeoEventReportingRequest, request.path == APIPath.GeoEventsReports{
				let jsonStr: String
                
				if request.eventsDataList.first?.campaignId == suspendedCampaignId {
					jsonStr = "{\"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"}, \"suspendedCampaignIds\": [\"\(suspendedCampaignId)\"]}"
				} else if request.eventsDataList.first?.campaignId == finishedCampaignId {
					jsonStr = "{\"messageIds\": {\"tm1\": \"m1\", \"tm2\": \"m2\", \"tm3\": \"m3\"}, \"finishedCampaignIds\": [\"\(finishedCampaignId)\"]}"
				} else {
					return nil
				}
				return JSON.parse(jsonStr)
			} else {
				return nil
			}
		})
	}
}
