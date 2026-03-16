//
//  MMNSEConstants.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

enum MMNSEConsts {
    enum API {
        static let prodBaseURLString = "https://mobile.infobip.com"
        static let deliveryReportPath = "/mobile/1/messages/deliveryreport"
        static let platformType = "APNS"
    }

    enum KeychainKeys {
        static let prefix = "com.mobile-messaging"
        static let pushRegId = "internalId"
        static let appCode = "appCode"
    }

    enum DynamicBaseUrl {
        static let newBaseUrlHeader = "New-Base-URL"
        static let storedDynamicBaseUrlKey = "com.mobile-messaging.dynamic-base-url"
    }

    enum DeliveryReport {
        static let dlrMessageIds = "dlrIds"
    }

    enum APNSPayloadKeys {
        static let aps = "aps"
        static let internalData = "internalData"
        static let messageId = "messageId"
        static let customPayload = "customPayload"
    }

    enum InternalDataKeys {
        static let attachments = "atts"
        static let sendDateTime = "sendDateTime"
        static let silent = "silent"
    }

    enum Attachments {
        enum Keys {
            static let url = "url"
        }
    }

    enum APIHeaders {
        static let foreground = "foreground"
        static let pushRegistrationId = "pushregistrationid"
        static let applicationcode = "applicationcode"
        static let installationId = "installationid"
        static let authorization = "Authorization"
        static let authorizationApiKey = "App"
        static let accept = "Accept"
        static let contentType = "Content-Type"
    }

    enum UserDefaultsKeys {
        static let universalInstallationId = "com.mobile-messaging.universal-installation-id"
    }

    enum InfoPlistKeys {
        static let appGroupId = "com.mobilemessaging.app_group"
    }
}
