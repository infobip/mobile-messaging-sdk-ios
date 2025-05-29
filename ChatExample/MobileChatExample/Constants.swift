//
//  Constants.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 10/02/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import Foundation

enum MainOptions: Int, CaseIterable {
    case uiKitChat = 0, swiftUIChat, webRTCUI, advancedChat
    var caseCount: Int {
        switch self {
        case .uiKitChat:
            return ShowChatOptions.allCases.count
        case .advancedChat:
            return AdvancedChatOptions.allCases.count
        case .webRTCUI:
            return WebRTCUIOptions.allCases.count
        case .swiftUIChat:
            return SwiftUIChatOptions.allCases.count
        }
    }
    
    func subOptionTitle(for index: Int) -> String? {
        switch self {
        case .uiKitChat:
            return ShowChatOptions(rawValue: index)?.title
        case .advancedChat:
            return AdvancedChatOptions(rawValue: index)?.title
        case .webRTCUI:
            return WebRTCUIOptions(rawValue: index)?.title
        case .swiftUIChat:
            return SwiftUIChatOptions(rawValue: index)?.title
        }
    }
}
enum ShowChatOptions: Int, CaseIterable {
    case pushNavigationItem = 0,
    presentModal,
    presentRootNavVC,
    presentRootNavVCCustomTansition,
    showInTabBar
    var title: String {
        switch self {
        case .pushNavigationItem:
            return "pushNavigationItem"
        case .presentModal:
            return "presentModal"
        case .presentRootNavVC:
            return "presentRootNavVC"
        case .presentRootNavVCCustomTansition:
            return "presentRootNavVC-CustomTansition"
        case .showInTabBar:
            return "showInTabBar"
        }
    }
}
enum AdvancedChatOptions: Int, CaseIterable {
    case setLanguage = 0,
    customisedChatInput,
    replacedChatInput,
    externalChatInputVC,
    presentSendingContextualData,
    sendContextualData,
    authenticatedChat,
    personalize,
    depersonalize,
    widgetAPI
    
    var title: String {
        switch self {
        case .setLanguage:
            return "setLanguage"
        case .customisedChatInput:
            return "customisedChatInput"
        case .replacedChatInput:
            return "replacedChatInput"
        case .presentSendingContextualData:
            return "presentChat-SendingContextualData"
        case .sendContextualData:
            return "Send contextual data"
        case .authenticatedChat:
            return "authenticatedChat"
        case .personalize:
            return "personalize"
        case .depersonalize:
            return "depersonalize"
        case .externalChatInputVC:
            return "externalChatInputVC"
        case .widgetAPI:
            return "widgetAPIChat"
        }
    }
}
enum WebRTCUIOptions: Int, CaseIterable {
    case restartCalls = 0, stopCall, copyIdentityToClipboard
    var title: String {
        switch self {
        case .restartCalls:
            return "restartCalls"
        case .stopCall:
            return "stopCall"
        case .copyIdentityToClipboard:
            return "copyIdentityToClipboard"
        }
    }
}

enum SwiftUIChatOptions: Int, CaseIterable {
    case defaultSwiftUIChat = 0, swiftUIChatWithExternalInput, swiftUIChatWithCustomNavigation
    var title: String {
        switch self {
        case .defaultSwiftUIChat:
            return "defaultSwiftUIChat"
        case .swiftUIChatWithExternalInput:
            return "swiftUIChatWithExternalInput"
        case .swiftUIChatWithCustomNavigation:
            return "swiftUIChatWithCustomNavigation"
        }
    }
}
