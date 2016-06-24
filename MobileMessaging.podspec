
# Be sure to run `pod lib lint MobileMessaging.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = "MobileMessaging"
s.version          = "0.2.1"
s.summary          = "Mobile Messaging SDK for iOS"
s.description      = <<-DESC
Mobile Messaging SDK is designed and developed to easily enable push notification channel in your mobile application. In almost no time of implementation you get push notification in you application and access to the features of Infobip IP Messaging Platform.
DESC

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

s.source_files = 'Pod/Classes/**/*.{c,h,hh,m,mm,swift}'

s.resource_bundles = {
'MobileMessaging' => ['Pod/Assets/*.png']
}

s.public_header_files = 'Pod/Classes/**/*.h'
s.private_header_files = 'Pod/Classes/Vendor/**/*.h'
s.frameworks = 'CoreData', 'CoreTelephony'
s.resources = 'Pod/Classes/Storage/*.xcdatamodeld', 'Pod/Classes/**/*.modulemap'
s.dependency 'Freddy', '~> 2.0'
s.dependency 'CocoaLumberjack'

# s.default_subspecs = 'HTTP', 'Operations', 'Vendor', 'Storage', 'Utils'

    # s.subspec 'HTTP' do |hs|
    #     hs.source_files = 'Pod/Classes/HTTP/**/*'
    #     hs.dependency 'MobileMessaging/Storage'
    # end

    # s.subspec 'Operations' do |os|
    #     os.source_files = 'Pod/Classes/Operations/**/*'
    # end

    # s.subspec 'Storage' do |ss|
    #     ss.source_files = 'Pod/Classes/Storage/**/*.swift'
    # end

    # s.subspec 'Utils' do |us|
    #     us.source_files = 'Pod/Classes/Utils/**/*'
    # end

    # s.subspec 'Vendor' do |vs|
    #     vs.subspec 'MagicalRecord' do |mvs|
    #          mvs.source_files = 'Pod/Classes/Vendor/**/*.{h,m}'
    #     end
    # end

end
