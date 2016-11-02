Pod::Spec.new do |s|
    s.name          = "MobileMessaging"
    s.version       = "2.0.2"
    s.summary       = "Mobile Messaging SDK for iOS"
    s.description   = "Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in you application and access to the features of Infobip IP Messaging Platform."
    s.homepage      = "https://github.com/infobip/mobile-messaging-sdk-ios"
    s.license       = 'MIT'
    s.authors       = { 'Andrey Kadochnikov' => 'andrey.kadochnikov@infobip.com', 'Olga Koroleva' => 'olga.koroleva@infobip.com' }
    s.source        = { :git => "https://github.com/infobip/mobile-messaging-sdk-ios.git", :tag => s.version }
    s.social_media_url = 'https://twitter.com/infobip'
    s.platform      = :ios, '8.0'
    s.requires_arc  = true
    s.pod_target_xcconfig =  {
        'ENABLE_TESTABILITY' => 'YES',
        'SWIFT_VERSION' => '3.0',
        'SWIFT_INCLUDE_PATHS' => '${PODS_ROOT}/MobileMessaging/Pod/Classes/Vendor/AFNetworking/** ${PODS_ROOT}/../../Pod/Classes/Vendor/AFNetworking/**',
        'OTHER_SWIFT_FLAGS[config=Debug]' => '-DDEBUG'
    }
    s.module_map    = 'Pod/MobileMessaging.modulemap'
    s.frameworks    = 'CoreData', 'CoreTelephony'
    s.resources     = 'Pod/Classes/MessageStorage/*.xcdatamodeld', 'Pod/Classes/InternalStorage/*.xcdatamodeld', 'Pod/Classes/**/*.modulemap'
    s.public_header_files = 'Pod/Classes/MMNotifications.h',
                            'Pod/Classes/MobileMessagingAppDelegateObjc.h',
                            'Pod/Classes/MobileMessagingCordovaApplicationDelegate.h'
    s.private_header_files = 'Pod/Classes/Vendor/**/*.h'
    s.source_files  = 'Pod/Classes/**/*.{h,m,swift}'
    s.exclude_files = 'Pod/Classes/Logging/DummyLogger/**'
    s.dependency 'SwiftyJSON', '~> 3.0'
    s.dependency 'CocoaLumberjack', '~> 3.0'
end
