//
//  ColorThemeVC.swift
//  MobileChatExample
//
//  Created by Maksym Svitlovskyi on 12/05/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import UIKit
import MobileMessaging
import WebRTCUI
import InAppChat

class ColorThemeTableVC: UITableViewController {
    
    var allThemes: [MMChatSettings.ColorTheme] = [.auto, .light, .dark]
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allThemes.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCell", for: indexPath)
        cell.textLabel?.text = {
            switch allThemes[indexPath.row] {
            case .auto: return "Auto"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MMChatSettings.colorTheme = allThemes[indexPath.row]
        dismiss(animated: true)
    }
}
