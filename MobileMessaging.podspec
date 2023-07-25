Pod::Spec.new do |s|
    s.name          = 'MobileMessaging'
    s.version       = '10.20.0'
    s.summary       = 'Mobile Messaging SDK for iOS'
    s.description   = 'Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in you application and access to the features of Infobip IP Messaging Platform.'
    s.homepage      = 'https://github.com/infobip/mobile-messaging-sdk-ios'
    s.license       = 'MIT'
    s.authors       = { 'Andrey Kadochnikov' => 'andrey.kadochnikov@infobip.com', 'Olga Koroleva' => 'olga.koroleva@infobip.com' }
    s.source        = { :git => 'https://github.com/infobip/mobile-messaging-sdk-ios.git', :tag => s.version }
    s.platform      = :ios
    s.ios.deployment_target = '12.0'
    s.swift_version = '5'
    s.requires_arc  = true
    s.pod_target_xcconfig =  {
        'SWIFT_VERSION' => '5',
        'OTHER_SWIFT_FLAGS[config=Debug]' => '$(inherited) -DDEBUG'
    }
    s.default_subspec = 'CocoaLumberjack'

    s.subspec 'Core' do |core|
        core.frameworks = 'CoreData', 'CoreTelephony', 'SystemConfiguration'
        core.resource_bundles = {'MMCore' => ['Classes/InteractiveNotifications/MessageAlert/*.xib', 'Classes/InteractiveNotifications/*.plist', 'Classes/Core/Localization/**/*.strings', 'Classes/MessageStorage/*.xcdatamodeld', 'Classes/Core/InternalStorage/*.xcdatamodeld', 'Classes/Core/InternalStorage/*.xcmappingmodel']}
        core.public_header_files = 'Classes/Core/**/*.h', 'Classes/Vendor/SwiftTryCatch/*.h'
        core.private_header_files = 'Classes/Vendor/Alamofire/*.h', 'Classes/Vendor/CryptoSwift/*.h', 'Classes/Vendor/Keychain/*.h', 'Classes/Vendor/Kingsfisher/*.h', 'Classes/Vendor/PSOperations/*.h', 'Classes/Vendor/SwiftyJSON/*.h'
        core.source_files = 'Classes/Core/**/*.{h,m,swift}', 'Classes/Vendor/**/*.{h,m,swift}', 'Classes/MessageStorage/**/*.{h,m,swift}', 'Classes/RichNotifications/**', 'Classes/UserSession/**', 'Classes/InteractiveNotifications/**/*.{h,m,swift}', 'Headers/Public/MobileMessaging/MobileMessaging-umbrella.h'
    end

    s.subspec 'CocoaLumberjack' do |cl|
        cl.dependency 'MobileMessaging/Core'
        cl.source_files = 'Classes/Logging/CocoaLumberjack/**/*.{h,m,swift}'
        cl.dependency 'CocoaLumberjack/Swift', '3.7.4'
    end

    s.subspec 'Geofencing' do |geo|
        geo.dependency 'MobileMessaging/Core'
        geo.frameworks = 'CoreLocation'
        geo.source_files = 'Classes/Geofencing/**/*.{h,m,swift}'
    end
    
    s.subspec 'InAppChat' do |chat|
        chat.frameworks = 'AudioToolbox'
        chat.dependency 'MobileMessaging/Core'
        chat.source_files = 'Classes/Chat/**/*.{h,m,swift}'
        chat.resource_bundles = {'MMInAppChat' => ['Classes/Chat/Resources/**/*.{xcassets,png,html}', 'Classes/Chat/Localization/**/*.strings']}
    end

    s.subspec 'Inbox' do |inbox|
        inbox.dependency 'MobileMessaging/Core'
        inbox.source_files = 'Classes/Inbox/**/*.{h,m,swift}'
    end

    s.subspec 'WebRTCUI' do |webrtcui|
        webrtcui.dependency 'MobileMessaging/Core'
        webrtcui.dependency 'InfobipRTC', '2.0.23'
        webrtcui.source_files = 'Classes/WebRTCUI/**/*.{h,m,swift,storyboard}'
        webrtcui.resource_bundles = {'MMWebRTCUI' => ['Classes/WebRTCUI/UI/**/*.{xcassets,png,wav,svg,html}',
            'Classes/WebRTCUI/UI/*.{storyboard}']}

        s.pod_target_xcconfig = {
            'SWIFT_VERSION' => '5',
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1 WEBRTCUI_ENABLED=1',
            'OTHER_SWIFT_FLAGS' => '$(inherited) -D WEBRTCUI_ENABLED'
        }        
    end
end
