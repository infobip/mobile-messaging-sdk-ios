Pod::Spec.new do |s|
    s.name          = 'MobileMessaging'
    s.version       = '12.2.3'
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
        core.resource_bundles =
        {
            'MMCore' => [
                            'Classes/MobileMessaging/Resources/InteractiveNotifications/*.xib',
                            'Classes/MobileMessaging/Resources/InteractiveNotifications/*.plist',
                            'Classes/MobileMessaging/Resources/Localization/**/*.strings',
                            'Classes/MobileMessaging/Resources/MessageStorage/*.xcdatamodeld',
                            'Classes/MobileMessaging/Resources/InternalStorage/*.xcdatamodeld',
                            'Classes/MobileMessaging/Resources/InternalStorage/*.xcmappingmodel'
                        ]
        }
        core.public_header_files =
            'Classes/MobileMessagingObjC/Headers/MobileMessagingPluginApplicationDelegate.h',
            'Classes/MobileMessagingObjC/Headers/MMNotifications.h',
            'Classes/MobileMessagingObjC/Headers/SwiftTryCatch.h'
        core.private_header_files =
            'Classes/MobileMessagingObjC/Headers/Alamofire.h',
            'Classes/MobileMessagingObjC/Headers/Kingsfisher.h'
        core.source_files =
            'Classes/MobileMessaging/Core/**/*.{h,m,swift}',
            'Classes/MobileMessaging/InteractiveNotifications/**/*.{h,m,swift}',
            'Classes/MobileMessaging/MessageStorage/**/*.{h,m,swift}',
            'Classes/MobileMessaging/RichNotifications/**/*.{h,m,swift}',
            'Classes/MobileMessaging/UserSession/**/*.{h,m,swift}',
            'Classes/MobileMessaging/Vendor/**/*.{h,m,swift}',
            'Classes/MobileMessagingObjC/Core/**/*.{h,m,swift}',
            'Classes/MobileMessagingObjC/Vendor/**/*.{h,m,swift}',
            'Classes/MobileMessagingObjC/Headers/**/*.{h,m,swift}',
            'Headers/Public/MobileMessaging/MobileMessaging-umbrella.h'
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
        webrtcui.dependency 'InfobipRTC', '2.2.8'
        webrtcui.source_files = 'Classes/WebRTCUI/**/*.{h,m,swift}'
        webrtcui.resource_bundles = {'MMWebRTCUI' => ['Classes/WebRTCUI/Resources/**/*.{xcassets,png,wav,svg,html}']}
        s.pod_target_xcconfig = {
            'SWIFT_VERSION' => '5',
            'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1 WEBRTCUI_ENABLED=1',
            'OTHER_SWIFT_FLAGS' => '$(inherited) -D WEBRTCUI_ENABLED'
        }    
    end
end
