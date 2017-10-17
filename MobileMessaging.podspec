Pod::Spec.new do |s|
    s.name          = "MobileMessaging"
    s.version       = "2.8.7"
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
    s.module_map = 'MobileMessaging.modulemap'

    s.subspec 'Core' do |core|
        core.frameworks = 'CoreData', 'CoreTelephony', 'SystemConfiguration'
        core.resources = 'Classes/MessageStorage/*.xcdatamodeld', 'Classes/Core/InternalStorage/*.xcdatamodeld', 'Classes/InteractiveNotifications/*.plist', 'Classes/Core/Localization/**/*.strings'
        core.public_header_files = 'Classes/Core/**/*.h','Classes/MobileMessaging-umbrella.h'
        core.private_header_files = 'Classes/Vendor/**/*.h'
        core.source_files = 'Classes/Core/**/*.{h,m,swift}', 'Classes/Vendor/**/*.{h,m,swift}', 'Classes/MessageStorage/**/*.{h,m,swift}', 'Classes/RichNotifications/**', 'Classes/InteractiveNotifications/**/*.{h,m,swift}', 'Classes/MobileMessaging-umbrella.h'
    end

    s.subspec 'CocoaLumberjack' do |cl|
		cl.dependency 'MobileMessaging/Core'
        cl.source_files = 'Classes/Logging/CocoaLumberjack/**/*.{h,m,swift}'
        cl.dependency 'CocoaLumberjack', '~> 3.1'
    end

    s.subspec 'Geofencing' do |geo|
		geo.dependency 'MobileMessaging/Core'
        geo.frameworks = 'CoreLocation'
        geo.source_files = 'Classes/Geofencing/**'
    end
end
