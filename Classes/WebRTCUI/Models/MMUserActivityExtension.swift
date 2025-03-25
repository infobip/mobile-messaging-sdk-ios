//
//  MMUserActivityExtension.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
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
