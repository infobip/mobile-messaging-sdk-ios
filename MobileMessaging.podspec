Pod::Spec.new do |s|
    s.name          = "MobileMessaging"
    s.version       = "1.0.4"
    s.summary       = "Mobile Messaging SDK for iOS"
    s.description   = "Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in you application and access to the features of Infobip IP Messaging Platform."
    s.homepage      = "https://github.com/infobip/mobile-messaging-sdk-ios"
    s.license       = 'MIT'
    s.authors       = { 'Andrey Kadochnikov' => 'andrey.kadochnikov@infobip.com', 'Olga Koroleva' => 'olga.koroleva@infobip.com' }
    s.source        = { :git => "https://github.com/infobip/mobile-messaging-sdk-ios.git", :tag => s.version }
    s.social_media_url = 'https://twitter.com/infobip'
    s.platform = :ios, '8.0'
    s.requires_arc = true
    s.pod_target_xcconfig =  {
    	'ENABLE_TESTABILITY' => 'YES',
    	'SWIFT_INCLUDE_PATHS' => '${PODS_ROOT}/MobileMessaging/Pod/Classes/Vendor/MagicalRecord/** ${PODS_ROOT}/MobileMessaging/Pod/Classes/Vendor/AFNetworking/** ${PODS_ROOT}/../../Pod/Classes/Vendor/MagicalRecord/** ${PODS_ROOT}/../../Pod/Classes/Vendor/AFNetworking/**'
    }
    s.default_subspec = 'CocoaLumberjack'

    s.subspec 'Core' do |core|
        core.frameworks = 'CoreData', 'CoreTelephony'
        core.resources = 'Pod/Classes/Storage/*.xcdatamodeld', 'Pod/Classes/**/*.modulemap'
        core.public_header_files = 'Pod/Classes/**/*.h'
        core.private_header_files = 'Pod/Classes/Vendor/**/*.h'
        core.source_files = 'Pod/Classes/**/*.{c,h,hh,m,mm,swift}'
        core.exclude_files = 'Pod/Classes/Logging/DummyLogger/**', 'Pod/Classes/Logging/CocoaLumberjack/**'
        core.dependency 'SwiftyJSON'    
    end

    s.subspec 'DummyLogger' do |d|
        d.source_files = 'Pod/Classes/Logging/DummyLogger/**'
        d.dependency 'MobileMessaging/Core'
    end

    s.subspec 'CocoaLumberjack' do |cl|
        cl.source_files = 'Pod/Classes/Logging/CocoaLumberjack/**'
        cl.dependency 'MobileMessaging/Core'
        cl.dependency 'CocoaLumberjack'
    end
end
