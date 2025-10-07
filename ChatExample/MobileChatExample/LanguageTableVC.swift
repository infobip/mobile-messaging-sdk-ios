// 
//  ChatExample/MobileChatExample/LanguageTableVC.swift
//  MobileChatExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit
import MobileMessaging
#if USING_SPM
import WebRTCUI
import InAppChat
import MobileMessagingLogging
#endif

class LanguageTableVC: UITableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MMLanguage.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath)
        let mmLanguage = MMLanguage.allCases[indexPath.row]
        cell.textLabel?.text = mmLanguage.localisedName
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MobileMessaging.inAppChat?.setLanguage(MMLanguage.allCases[indexPath.row].locale)
        dismiss(animated: true)
    }
}
