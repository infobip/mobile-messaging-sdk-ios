// 
//  MMLanguage.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

private let MMUserDefaultChatLanguageKey = "MMInAppChatLanguage"

struct ResolvedLanguage {
    let chatLanguage: MMLanguage
    let resourceCode: String
    let resourceIsRightToLeft: Bool

    init(chatLanguage: MMLanguage, resourceCode: String) {
        self.chatLanguage = chatLanguage
        self.resourceCode = resourceCode
        self.resourceIsRightToLeft = Locale.characterDirection(forLanguage: resourceCode) == .rightToLeft
    }
}

/// Enumerator defining the supported languages of the InAppChat and some string operations and helpers
@objc public enum MMLanguage: Int, CaseIterable {
    case en = 0,
         de,
         tr,
         ko,
         ru,
         ja,
         zhHans,
         zhHant,
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
         sr,
         sw,
         rw,
         lg

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
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
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
        case .sw:
            return "sw"
        case .rw:
            return "rw"
        case .lg:
            return "lg"
        }
    }
    
    /// Mapping from ISO language to enumeration
    public static func mapLanguage(from value: String) -> MMLanguage {
        return supportedLanguage(from: value) ?? .en
    }

    static func preferredResourceLanguage(availableLocalizations: [String], preferredLanguages: [String]) -> String {
        let normalizedPreferences = preferredLanguages.map {
            $0.replacingOccurrences(of: "_", with: "-")
        }

        let matchedLocalizations = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: normalizedPreferences
        )
        if let match = matchedLocalizations.first,
           let localization = availableLocalizations.first(where: {
               $0.caseInsensitiveCompare(match) == .orderedSame
           }) {
            return localization
        }

        // English is included in both SDK resource bundles.
        return "en"
    }

    static func resolveLanguages(availableLocalizations: [String], preferredLanguages: [String], overrideLanguage: String? = nil) -> ResolvedLanguage {
        let chatLanguage = overrideLanguage.map { mapLanguage(from: $0) }
            ?? (preferredLanguages.lazy.compactMap { supportedLanguage(from: $0) }.first ?? .en)
        let resourcePreferences = overrideLanguage.map { [$0] + preferredLanguages } ?? preferredLanguages
        let resourceCode = preferredResourceLanguage(
            availableLocalizations: availableLocalizations,
            preferredLanguages: resourcePreferences
        )
        return ResolvedLanguage(chatLanguage: chatLanguage, resourceCode: resourceCode)
    }

    private static let systemLanguages = Locale.preferredLanguages
    private static let availableResourceLocalizations = MobileMessaging.resourceBundle.localizations
    private static let systemSelection = resolveLanguages(
        availableLocalizations: availableResourceLocalizations,
        preferredLanguages: systemLanguages
    )
    private static let selectionLock = NSRecursiveLock()
    private static var cachedSelection: ResolvedLanguage = {
        guard let override = UserDefaults.standard.string(forKey: MMUserDefaultChatLanguageKey) else {
            return systemSelection
        }
        return resolveLanguages(
            availableLocalizations: availableResourceLocalizations,
            preferredLanguages: systemLanguages,
            overrideLanguage: override
        )
    }()

    private static var selectedLanguages: ResolvedLanguage {
        selectionLock.lock()
        defer { selectionLock.unlock() }
        return cachedSelection
    }

    private static func supportedLanguage(from value: String) -> MMLanguage? {
        let components = value.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map { $0.lowercased() }
        if components.first == "zh" {
            if components.contains("hant") {
                return .zhHant
            }
            if components.contains("hans") {
                return .zhHans
            }
            if components.contains(where: { ["tw", "hk", "mo"].contains($0) }) { return .zhHant }
            if components.contains(where: { ["cn", "sg"].contains($0) }) { return .zhHans }
            return .zhHans
        }
        switch components.first ?? "" {
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
        case "sw":
            return .sw
        case "rw":
            return .rw
        case "lg":
            return .lg
        default:
            return nil
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
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
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
        case .sw:
            return "sw-KE"
        case .rw:
            return "rw-RW"
        case .lg:
            return "lg-UG"
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
        case .zhHans:
            return "简体中文"
        case .zhHant:
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
        case .sw:
            return "Kiswahili"
        case .rw:
            return "Ikinyarwanda"
        case .lg:
            return "Luganda"
        }
    }
    
    /// Backend-supported chat language for the explicit SDK choice or the preferred system languages.
    public static var sessionLanguage: MMLanguage {
        get { selectedLanguages.chatLanguage }
        set {
            setSessionLanguage(fromLocale: newValue.stringValue)
        }
    }

    /// Stores the requested locale so native strings can use it even when the backend language falls back to English.
    public static func setSessionLanguage(fromLocale locale: String) {
        setSessionLanguageOverride(locale)
    }

    static func setSessionLanguageOverride(_ locale: String?) {
        let selection = locale.map {
            resolveLanguages(
                availableLocalizations: availableResourceLocalizations,
                preferredLanguages: systemLanguages,
                overrideLanguage: $0
            )
        } ?? systemSelection

        selectionLock.lock()
        defer { selectionLock.unlock() }
        if let locale {
            UserDefaults.standard.set(locale, forKey: MMUserDefaultChatLanguageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: MMUserDefaultChatLanguageKey)
        }
        cachedSelection = selection
    }

    /// Language of bundled SDK strings; may differ from the backend chat language.
    public static var resourceLanguageCode: String {
        selectedLanguages.resourceCode
    }

    /// Text direction of the selected bundled native strings. This can differ from `sessionLanguage`.
    public static var resourceLanguageIsRightToLeft: Bool {
        selectedLanguages.resourceIsRightToLeft
    }

    /// Whether this language is written right-to-left.
    /// This describes this enum value, not necessarily the selected bundled strings;
    /// use `resourceLanguageIsRightToLeft` for the current SDK resource direction.
    public var isRightToLeft: Bool {
        return self == .ar
    }
}
