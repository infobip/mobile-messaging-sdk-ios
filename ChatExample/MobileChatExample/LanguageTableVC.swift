//
//  LanguageTableVC.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 08/06/2022.
//  Copyright © 2022 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging

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
