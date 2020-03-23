//
//  UserSessionReportObject+CoreDataClass.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 20.01.2020.
//
//

import Foundation
import CoreData


final class UserSessionReportObject: NSManagedObject, FetchableResult {
	var sessionId: String {
		return "\(self.pushRegistrationId)_\(self.startDate.timeIntervalSince1970)"
	}
}
