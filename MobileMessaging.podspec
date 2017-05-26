Pod::Spec.new do |s|
    s.name          = "MobileMessaging"
    s.version       = "2.5.9"
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
		'SWIFT_VERSION' => '3.0.1',
        'OTHER_SWIFT_FLAGS[config=Debug]' => '-DDEBUG'
    }

    s.default_subspec = 'CocoaLumberjack'
    s.module_map = 'Pod/MobileMessaging.modulemap'

    s.subspec 'Core' do |core|
        core.frameworks = 'CoreData', 'CoreTelephony', 'SystemConfiguration'
        core.resources = 'Pod/Classes/MessageStorage/*.xcdatamodeld', 'Pod/Classes/Core/InternalStorage/*.xcdatamodeld'
        core.public_header_files = 'Pod/Classes/Core/**/*.h'
        core.private_header_files = 'Pod/Classes/Vendor/**/*.h'
        core.source_files = 'Pod/Classes/Core/**/*.{h,m,swift}', 'Pod/Classes/Vendor/**/*.{h,m,swift}', 'Pod/Classes/MessageStorage/**/*.{h,m,swift}', 'Pod/Classes/RichNotifications/**'
    end

    s.subspec 'CocoaLumberjack' do |cl|
		cl.dependency 'MobileMessaging/Core'
        cl.source_files = 'Pod/Classes/Logging/CocoaLumberjack/**/*.{h,m,swift}'
        cl.dependency 'CocoaLumberjack', '~> 3.1'
    end

    s.subspec 'Geofencing' do |geo|
		geo.dependency 'MobileMessaging/Core'
        geo.frameworks = 'CoreLocation'
        geo.source_files = 'Pod/Classes/Geofencing/**'
    end
end
