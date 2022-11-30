platform :ios, '12.0'
use_frameworks!
# ignore all warnings from all pods
inhibit_all_warnings!
def includePods
 pod 'InfobipRTC', '1.5.9'
end

workspace 'MobileMessaging'
project 'infobip-mobile-messaging-ios/MobileMessaging.xcodeproj'

target 'MobileMessaging' do
  project 'MobileMessaging.xcodeproj'
  includePods
end
