//
//  SettingsTableViewController.swift
//  MobileMessaging
//
//  Created by okoroleva on 05.04.16.
//

import UIKit
import MobileMessaging

let kSettingCellId = "kSettingCellId"

class InfoTableViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    enum SettingsCell: Int {
        case deviceToken
        case internalId
        
		var text: String {
            switch self {
            case .deviceToken: return "APNs Device token: "
            case .internalId: return "Internal Registration Id: "
            }
        }
        
        static let count: Int = {
            var max: Int = 0
            while let _ = SettingsCell(rawValue: max) { max += 1 }
            return max
        }()
    }
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(CopyableCell.self, forCellReuseIdentifier: kSettingCellId)
		tableView.estimatedRowHeight = 44
		NotificationCenter.default.addObserver(self, selector: #selector(InfoTableViewController.registrationChanged), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(InfoTableViewController.registrationChanged), name: NSNotification.Name(rawValue: MMNotificationDeviceTokenReceived), object: nil)
    }
    
    @IBAction func closeButtonClicked(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion:nil)
    }
    
    //MARK: Notification
	func registrationChanged() {
		tableView.reloadData()
	}
	
    //MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
    }
	
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsCell.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsCell(rawValue: section)?.text
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kSettingCellId, for: indexPath)
        cell.textLabel?.numberOfLines = 0
		
		var settingValue : String?
		switch indexPath.section {
		case SettingsCell.deviceToken.rawValue:
			settingValue = MobileMessaging.currentInstallation?.deviceToken
		case SettingsCell.internalId.rawValue:
			settingValue = MobileMessaging.currentUser?.pushRegistrationId
		default: break
		}
		
		cell.textLabel?.text = settingValue
        return cell
    }
}
