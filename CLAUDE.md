# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Mobile Messaging SDK for iOS** by Infobip - a comprehensive push notification and mobile messaging framework. It's a Swift-based SDK (minimum iOS 15.0, Swift 5.5+) that provides push notifications, in-app messaging, chat functionality, inbox features, and WebRTC UI capabilities.

## Architecture

### Core Components Structure

The SDK follows a modular architecture with the main components in the `Classes/` directory:

- **`Classes/MobileMessaging/Core/`** - Main SDK core functionality
  - `MobileMessaging.swift` - Primary facade class and entry point
  - `Installation/` - Device registration and installation management
  - `Message/` - Message handling and processing
  - `User/` - User management and personalization
  - `HTTP/` - Network layer and API communication
  - `InternalStorage/` - Core data persistence
  - `Operations/` - Asynchronous operation management

- **`Classes/MobileMessaging/`** - Additional core modules
  - `MessageStorage/` - Message persistence layer
  - `UserSession/` - Session management
  - `InteractiveNotifications/` - Rich notification handling
  - `RichNotifications/` - Media-rich push notifications
  - `Vendor/` - Third-party integrations

- **`Classes/MobileMessagingObjC/`** - Objective-C bridge components

- **Optional Modules:**
  - `Classes/Chat/` - In-app chat functionality
  - `Classes/Inbox/` - Message inbox features
  - `Classes/WebRTCUI/` - WebRTC video calling UI
  - `Classes/Logging/` - CocoaLumberjack integration

### Distribution Methods

The SDK supports multiple integration methods:

1. **Swift Package Manager** (Package.swift) - Primary modern distribution
2. **CocoaPods** (MobileMessaging.podspec) - Traditional dependency management
3. **Carthage** - Framework-based integration

### Modular Design

Each module is designed as an optional subspec/target:
- Core module provides base functionality
- Optional modules (InAppChat, Inbox, WebRTCUI, Logging) can be added as needed
- Default includes CocoaLumberjack for logging

## Development Commands

### Building and Testing

**Run tests:**
```bash
# Main test suite (via Travis CI configuration)
xcodebuild test -workspace Example/MobileMessaging.xcworkspace -scheme MobileMessaging-Example -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO | xcpretty

# CocoaPods validation
pod lib lint
```

**Working with Examples:**
- `Example/` - Main CocoaPods example project
- `Example_SPM/` - Swift Package Manager example
- `Example_static/` - Static library example
- `ChatExample/` - In-app chat demo
- `InboxExample/` - Inbox functionality demo
- `SPMChatExample/` - SPM-based chat demo
- `ChatSwiftUIDemo/` - SwiftUI chat implementation

### Development Utilities

**Localization Management:**
```bash
# Generate localized string constants from resources
./localiseStrings.sh
```
This script generates `Classes/MobileMessaging/Core/Utils/MMLoc.swift` from localization files.

**Code Quality:**
- Uses SonarQube for code analysis (sonar-project.properties)
- SwiftLint integration for code style
- Coverage reporting via `xccov-to-sonarqube-generic.sh`

## Key Architecture Patterns

### Initialization Flow
The SDK uses a fluent builder pattern for configuration:
```swift
MobileMessaging.withApplicationCode("your-app-code", notificationType: userNotificationType)
    .withDefaultMessageStorage()
    .withFullFeaturedInApps()
    .start()
```

### Message Storage Architecture
- Pluggable storage system via `MMMessageStorage` protocol
- Default implementation with Core Data
- Queue-based adapter pattern (`MessageStorageQueuedAdapter`)

### Notification Handling
- `UserNotificationCenterDelegate` for iOS notification center integration
- `MessageHandlingDelegate` for custom message processing
- Rich notifications with media attachments support

### User Management
- Installation-based tracking (device-centric)
- User personalization and custom attributes
- Privacy-compliant data handling

## Testing Structure

**Test Location:** `Example/Tests/MobileMessagingTests/`
- Unit tests integrated with main Example project
- Mock objects in `Example/Tests/mocks/`
- Device-specific test configurations

**CI/CD:** Travis CI configuration in `.travis.yml`

## Important Files

- `MobileMessaging.podspec` - CocoaPods specification and module definitions
- `Package.swift` - Swift Package Manager configuration
- `MobileMessaging.xcodeproj/` - Main Xcode project
- `Framework/MobileMessaging.xcconfig` - Build configuration
- `MobileMessaging-umbrella.h` - Objective-C umbrella header

## Development Notes

### Privacy and Security
- Privacy manifest included (`PrivacyInfo.xcprivacy`)
- Supports privacy-compliant data collection
- Application code obfuscation recommended for production

### Vendor Dependencies
- InfobipRTC (exact version 2.6.2) for WebRTC functionality
- CocoaLumberjack (3.8.5+) for logging
- Minimal external dependencies in core module

### Build Targets
The project supports multiple deployment targets and can be built as:
- Dynamic framework (default)
- Static library (Example_static)
- Swift Package Manager package