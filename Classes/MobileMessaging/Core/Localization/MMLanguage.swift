//
//  MMLanguage.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 07/06/2022.
//

import Foundation

private let MMUserDefaultChatLanguageKey = "MMInAppChatLanguage"

/// Enumerator defining the supported languages of the InAppChat and some string operations and helpers
@objc public enum MMLanguage: Int, CaseIterable {
    case en = 0,
         de,
         tr,
         ko,
         ru,
         ja,
         zh,
         es,
         pt,
         pl,
         ro,
         ar,
         bs,
         hr,
         el,
         sv,
         th,
         lt,
         da,
         lv,
         hu,
         it,
         fr,
         sl,
         uk,
         sq,
         sr

    /// stringValue is used for mapping a locale to a ISO language. For example, "" "es_ES" and "es_AR" will both be considered "es". We support also the separator "-", so possible formats are "es", "es_ES" and "es-ES", in order to use the system Locale.current easily.
    public var stringValue: String {
        switch self {
        case .en:
            return "en"
        case .de:
            return "de"
        case .tr:
            return "tr"
        case .ko:
            return "ko"
        case .ru:
            return "ru"
        case .ja:
            return "ja"
        case .zh:
            return "zh"
        case .es:
            return "es"
        case .pt:
            return "pt"
        case .pl:
            return "pl"
        case .ro:
            return "ro"
        case .ar:
            return "ar"
        case .bs:
            return "bs"
        case .hr:
            return "hr"
        case .el:
            return "el"
        case .sv:
            return "sv"
        case .th:
            return "th"
        case .lt:
            return "lt"
        case .da:
            return "da"
        case .lv:
            return "lv"
        case .hu:
            return "hu"
        case .it:
            return "it"
        case .fr:
            return "fr"
        case .sl:
            return "sl"
        case .uk:
            return "uk"
        case .sq:
            return "sq"
        case .sr:
            return "sr"
        }
    }
    
    /// Mapping from ISO language to enumeration
    public static func mapLanguage(from value: String) -> MMLanguage {
        switch value {
        case "en":
            return .en
        case "de":
            return .de
        case "tr":
            return .tr
        case "ko":
            return .ko
        case "ru":
            return .ru
        case "ja":
            return .ja
        case "zh":
            return .zh
        case "es":
            return .es
        case "pt":
            return .pt
        case "pl":
            return .pl
        case "ro":
            return .ro
        case "ar":
            return .ar
        case "bs":
            return .bs
        case "hr":
            return .hr
        case "el":
            return .el
        case "sv":
            return .sv
        case "th":
            return .th
        case "lt":
            return .lt
        case "da":
            return .da
        case "lv":
            return .lv
        case "hu":
            return .hu
        case "it":
            return .it
        case "fr":
            return .fr
        case "sl":
            return .sl
        case "uk":
            return .uk
        case "sq":
            return .sq
        case "sr":
            return .sr
        default:
            return .en
        }
    }
    
    /// Expected constant locales supported by backend.
    public var locale: String {
        switch self {
        case .en:
            return "en-US"
        case .de:
            return "de-DE"
        case .tr:
            return "tr-TR"
        case .ko:
            return "ko-KR"
        case .ru:
            return "ru-RU"
        case .ja:
            return "ja-JP"
        case .zh:
            return "zh-TW"
        case .es:
            return "es-LA"
        case .pt:
            return "pt-BR"
        case .pl:
            return "pl-PL"
        case .ro:
            return "ro-RO"
        case .ar:
            return "ar-AE"
        case .bs:
            return "bs-BA"
        case .hr:
            return "hr-HR"
        case .el:
            return "el-GR"
        case .sv:
            return "sv-SE"
        case .th:
            return "th-TH"
        case .lt:
            return "lt-LT"
        case .da:
            return "da-DK"
        case .lv:
            return "lv-LV"
        case .hu:
            return "hu-HU"
        case .it:
            return "it-IT"
        case .fr:
            return "fr-FR"
        case .sl:
            return "sl-SI"
        case .uk:
            return "uk-UA"
        case .sq:
            return "sq-AL"
        case .sr:
            return "sr-Latn"
        }
    }

    /// Translated languages names for UI purposes
    public var localisedName: String {
        switch self {
        case .en:
            return "English"
        case .de:
            return "Deutsch"
        case .tr:
            return "Türkçe"
        case .ko:
            return "한국어"
        case .ru:
            return "Русский"
        case .ja:
            return "日本語"
        case .zh:
            return "繁體中文"
        case .es:
            return "Español"
        case .pt:
            return "Português"
        case .pl:
            return "Polski"
        case .ro:
            return "Românește"
        case .ar:
            return "العربية"
        case .bs:
            return "босански"
        case .hr:
            return "Hrvatski"
        case .el:
            return "Ελληνικά"
        case .sv:
            return "Svenska"
        case .th:
            return "Thai"
        case .lt:
            return "Lietuvių"
        case .da:
            return "Dansk"
        case .lv:
            return "Latviešu"
        case .hu:
            return "Magyar"
        case .it:
            return "Italiano"
        case .fr:
            return "Français"
        case .sl:
            return "Slovenščina"
        case .uk:
            return "украї́нська"
        case .sq:
            return "Shqip"
        case .sr:
            return "Srpski"
        }
    }
    
    // Session language starts being the installation language (or english as default), but can be modified in runtime,
    // for example through chat methods. It will be used for accessing language bundle.
    public static var sessionLanguage: MMLanguage {
        get {
            let liveChatLanguage = UserDefaults.standard.object(forKey: MMUserDefaultChatLanguageKey) as? String
            let installationLanguage = MobileMessaging.currentInstallation?.language ?? "en"
            return MMLanguage.mapLanguage(from: liveChatLanguage ?? installationLanguage)
        }
        set {
            UserDefaults.standard.set(newValue.stringValue, forKey: MMUserDefaultChatLanguageKey)
        }
    }    
}
