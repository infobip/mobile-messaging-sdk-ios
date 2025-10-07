// 
//  MMUserActivityExtension.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Intents

extension NSUserActivity {
    var startCallHandle: String? {
        return (interaction?.intent as? INStartCallIntent)?.contacts?.first?.personHandle?.value
    }
    
    var video: Bool? {
        guard
            let interaction = interaction,
            let startCallIntent = interaction.intent as? SupportedStartCallIntent
            else {
                return nil
        }
        
        return startCallIntent is INStartCallIntent
    }
    
}

protocol SupportedStartCallIntent {
    var contacts: [INPerson]? { get }
}

extension INStartCallIntent: SupportedStartCallIntent {}
