//
//  MMGeofencingServiceTestUtils.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 13/11/2018.

//

import Foundation
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

class GeofencingServiceAlwaysRunningStub: MMGeofencingService {
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

	override func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMGeofencingCapabilityStatus) -> Void) {
		completion(.authorized)
	}

	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}

	override func onEnter(datasourceRegion: MMRegion, completion: @escaping () -> Void) {
		self.didEnterRegionCallback?(datasourceRegion)
		completion()
	}

	override func suspend() {
		eventsHandlingQueue.cancelAllOperations()
		self.isRunning = false
		stubbedLocationManager.monitoredRegionsArray = [CLRegion]()
	}

	override public class var currentCapabilityStatus: MMGeofencingCapabilityStatus {
		return MMGeofencingCapabilityStatus.authorized
	}
}

class GeofencingServiceDisabledStub: MMGeofencingService {
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

	override func authorizeService(kind: MMLocationServiceKind, usage: MMLocationServiceUsage, completion: @escaping (MMGeofencingCapabilityStatus) -> Void) {
		completion(.denied)
	}

	override func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {}

	override func onEnter(datasourceRegion: MMRegion, completion: @escaping () -> Void) {
		self.didEnterRegionCallback?(datasourceRegion)
		completion()
	}

	override func suspend() {
		eventsHandlingQueue.cancelAllOperations()
		self.isRunning = false
		locationManagerStub.monitoredRegionsArray = [CLRegion]()
	}

	override public class var currentCapabilityStatus: MMGeofencingCapabilityStatus {
		return MMGeofencingCapabilityStatus.denied
	}
}

let expectedCampaignId = "campaign 1"
let expectedMessageId = "message 1"
let expectedCampaignText = "campaign text"
let expectedCampaignTitle = "campaign title"
let expectedInAppDismissBtnTitle = "Dismiss Button"
let expectedInAppOpenBtnTitle = "Open Button"
let expectedContentUrl = "http://hello.com"
let expectedInAppWebViewUrl = "http://hello.com"
let expectedInAppBrowserUrl = "http://hello.com"
let expectedInAppDeeplink = "mydomain://hello.com/first/second"
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

var buddhistCalendarDate_06_08_2560__12_20_16: Date {
	let comps = NSDateComponents()
	comps.year = 2560
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16

	comps.calendar = Calendar(identifier: Calendar.Identifier.buddhist)
	comps.timeZone = TimeZone(secondsFromGMT: 0)
	return comps.date!
}

var japCalendarDate_06_08_0029__12_20_16: Date {
	let comps = NSDateComponents()
	comps.year = 29
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16

	comps.calendar = Calendar(identifier: Calendar.Identifier.japanese)
	comps.timeZone = TimeZone(secondsFromGMT: 0)
	return comps.date!
}


var gregorianCalendarDate_06_08_2017__12_20_16: Date {
	let comps = NSDateComponents()
	comps.year = 2017
	comps.month = 8
	comps.day = 6
	comps.hour = 12
	comps.minute = 20
	comps.second = 16

	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	comps.timeZone = TimeZone(secondsFromGMT: 0)
	return comps.date!
}



func baseAPNSDict(messageId: String = expectedMessageId) -> MMAPNSPayload {
	return
		[
			Consts.APNSPayloadKeys.messageId: messageId,
			Consts.APNSPayloadKeys.aps: [
				Consts.APNSPayloadKeys.contentAvailable: 1
			]
	]
}

let zagrebId = "6713245DA3638FDECFE448C550AD7681"
let pulaId = "A277A2A0D0612AFB652E9D2D80E02BF2"
let nestedPulaId = "M227A2A0D0612AFB652E9D2D80E0ZZ44"


// modern:
let modernZagrebDict: MMAPNSPayload = [
	GeoConstants.RegionKeys.identifier: zagrebId,
	GeoConstants.RegionKeys.latitude: 45.80869126677998,
	GeoConstants.RegionKeys.longitude: 15.97206115722656,
	GeoConstants.RegionKeys.radius: 9492.0,
	GeoConstants.RegionKeys.title: "Zagreb"
]

let modernPulaDict: MMAPNSPayload = [
	GeoConstants.RegionKeys.identifier: pulaId,
	GeoConstants.RegionKeys.latitude: 44.86803631018752,
	GeoConstants.RegionKeys.longitude: 13.84586334228516,
	GeoConstants.RegionKeys.radius: 5257.0,
	GeoConstants.RegionKeys.title: "Pula"
]

let nestedPulaDict: MMAPNSPayload = [
	GeoConstants.RegionKeys.identifier: nestedPulaId,
	GeoConstants.RegionKeys.latitude: 44.868036310,
	GeoConstants.RegionKeys.longitude: 13.845863342,
	GeoConstants.RegionKeys.radius: 5157.0,
	GeoConstants.RegionKeys.title: "Pula smaller"
]

var modernInternalDataWithZagrebPulaDict: MMAPNSPayload {
	var result = makeBaseInternalDataDict(campaignId: expectedCampaignId)
	result[Consts.InternalDataKeys.geo] = [modernZagrebDict, modernPulaDict]
	return result
}

var modernAPNSPayloadZagrebPulaDict: MMAPNSPayload {
	return (baseAPNSDict() + [Consts.APNSPayloadKeys.internalData: modernInternalDataWithZagrebPulaDict])!
}

// jsons
let jsonStr = """
{
"aps": {
"content-available": 1
},
"messageId": "lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=",
"internalData": {
"campaignId": "\(expectedCampaignId)",
"silent": {
	"body": "\(expectedCampaignText)",
    "title": "\(expectedCampaignTitle)",
	"sound": "\(expectedSound)"
},
"atts": [{"url": "\(expectedContentUrl)"}],
"startTime": "\(expectedStartDateString)",
"expiryTime": "\(expectedExpiryDateString)",
"inApp": 1,
"inAppStyle": 1,
"inAppDismissTitle": "\(expectedInAppDismissBtnTitle)",
"inAppOpenTitle": "\(expectedInAppOpenBtnTitle)",
"webViewUrl": "\(expectedInAppWebViewUrl)",
"browserUrl": "\(expectedInAppBrowserUrl)",
"deeplink": "\(expectedInAppDeeplink)",
"geo": [
{
"id": "\(zagrebId)",
"latitude": 45.80869126677998,
"longitude": 15.97206115722656,
"radiusInMeters": 9492.0,
"title": "Zagreb"
},
{
"id": "\(pulaId)",
"latitude": 44.86803631018752,
"longitude": 13.84586334228516,
"radiusInMeters": 5257.0,
"title": "Pula"
}
]
}
}
"""

let jsonStrFromPushUp = """
{
"aps": {
"sound": "\(expectedSound)",
"alert": {
    "body": "\(expectedCampaignText)",
    "title": "\(expectedCampaignTitle)"
},
"silent": true,
},
"messageId": "lY8Ja3GKmeN65J5hNlL9B9lLA9LrN//C/nH75iK+2KI=",
"internalData": {
"campaignId": "\(expectedCampaignId)",
"messageType":"geo",
"silent": {
    "body": "\(expectedCampaignText)",
    "title": "\(expectedCampaignTitle)",
    "sound": "\(expectedSound)"
},
"atts": [{"url": "\(expectedContentUrl)"}],
"startTime": "\(expectedStartDateString)",
"expiryTime": "\(expectedExpiryDateString)",
"inApp": 1,
"inAppStyle": 1,
"inAppDismissTitle": "\(expectedInAppDismissBtnTitle)",
"inAppOpenTitle": "\(expectedInAppOpenBtnTitle)",
"webViewUrl": "\(expectedInAppWebViewUrl)",
"browserUrl": "\(expectedInAppBrowserUrl)",
"deeplink": "\(expectedInAppDeeplink)",
"geo": [
{
"id": "\(zagrebId)",
"latitude": 45.80869126677998,
"longitude": 15.97206115722656,
"radiusInMeters": 9492.0,
"title": "Zagreb"
},
{
"id": "\(pulaId)",
"latitude": 44.86803631018752,
"longitude": 13.84586334228516,
"radiusInMeters": 5257.0,
"title": "Pula"
}
]
}
}
"""


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

func makeBaseInternalDataDict(campaignId: String) -> MMAPNSPayload {
	return
		[
			GeoConstants.CampaignKeys.campaignId: campaignId,
			GeoConstants.CampaignKeys.startDate: expectedStartDateString,
			GeoConstants.CampaignKeys.expiryDate: expectedExpiryDateString,
			Consts.InternalDataKeys.silent: [Consts.APNSPayloadKeys.body: expectedCampaignText, Consts.APNSPayloadKeys.sound: expectedSound],
			Consts.InternalDataKeys.messageType: Consts.InternalDataKeys.messageTypeGeo
	]
}

func makeApnsPayloadWithoutRegionsDataDict(campaignId: String, messageId: String) -> MMAPNSPayload {
	return (baseAPNSDict(messageId: messageId) + [Consts.APNSPayloadKeys.internalData: makeBaseInternalDataDict(campaignId: campaignId)])!
}

func makeApnsPayload(withEvents events: [MMAPNSPayload]?, deliveryTime: MMAPNSPayload?, regions: [MMAPNSPayload], campaignId: String = expectedCampaignId, messageId: String = expectedMessageId) -> MMAPNSPayload {
	var result = makeApnsPayloadWithoutRegionsDataDict(campaignId: campaignId, messageId: messageId)
	var internalData = result[Consts.APNSPayloadKeys.internalData] as! MMAPNSPayload
	internalData[Consts.InternalDataKeys.geo] = regions
	internalData[Consts.InternalDataKeys.event] = events ?? [defaultEvent]
	internalData[Consts.InternalDataKeys.deliveryTime] = deliveryTime
	let distantFutureDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date.distantFuture)
	internalData[GeoConstants.CampaignKeys.expiryDate] = distantFutureDateString
	result[Consts.APNSPayloadKeys.internalData] = internalData
	return result
}

func makeEventDict(ofType type: RegionEventType, limit: Int, timeout: Int? = nil) -> MMAPNSPayload {
	var result: MMAPNSPayload = [GeoConstants.RegionEventKeys.type: type.rawValue,
							   GeoConstants.RegionEventKeys.limit: limit]
	result[GeoConstants.RegionEventKeys.timeout] = timeout
	return result
}

func makeDeliveryTimeDict(withTimeIntervalString timeInterval: String? = nil, daysString days: String? = nil) -> MMAPNSPayload? {
	var result = MMAPNSPayload()
	result[GeoConstants.RegionDeliveryTimeKeys.timeInterval] = timeInterval
	result[GeoConstants.RegionDeliveryTimeKeys.days] = days
	return result.isEmpty ? nil : result
}

var defaultEvent = ["limit": 1, "rate": 0, "timeoutInMinutes": 0, "type": "entry"] as MMAPNSPayload

var succeedingApiStub: RemoteGeoAPIProviderStub = {
	let remoteApiProvider = RemoteGeoAPIProviderStub()
	remoteApiProvider.reportGeoEventClosure = { _,_,_,_ -> GeoEventReportingResult in
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
	return remoteApiProvider
}()

var failingApiStub: RemoteGeoAPIProviderStub = {
	let remoteApiProvider = RemoteGeoAPIProviderStub()
	remoteApiProvider.reportGeoEventClosure = { _,_,_,_ -> GeoEventReportingResult in
		return GeoEventReportingResult.Failure(MMInternalErrorType.UnknownError.foundationError)
	}
	return remoteApiProvider
}()
