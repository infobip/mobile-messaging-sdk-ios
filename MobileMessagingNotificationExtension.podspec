Pod::Spec.new do |s|
    s.name          = 'MobileMessagingNotificationExtension'
    s.module_name   = 'MobileMessagingNotificationExtension'
    s.version       = '15.0.0'
    s.summary       = 'Lightweight Mobile Messaging SDK for Notification Service Extension'
    s.description   = 'A standalone, zero-dependency module for iOS Notification Service Extensions. Handles delivery reporting and rich push notification content downloading without linking the full MobileMessaging SDK.'
    s.homepage      = 'https://github.com/infobip/mobile-messaging-sdk-ios'
    s.license       = 'MIT'
    s.authors       = { 'Team Mobile Messaging' => 'Team_Mobile_Messaging@infobip.com' }
    s.source        = { :git => 'https://github.com/infobip/mobile-messaging-sdk-ios.git', :tag => s.version }
    s.platform      = :ios
    s.ios.deployment_target = '15.0'
    s.swift_version = '5.5'
    s.requires_arc  = true
    s.source_files  = 'Classes/NotificationExtension/**/*.swift'
    s.frameworks    = 'UserNotifications', 'Security'
    s.pod_target_xcconfig = {
        'SWIFT_VERSION' => '5.5',
        'APPLICATION_EXTENSION_API_ONLY' => 'YES'
    }
end
