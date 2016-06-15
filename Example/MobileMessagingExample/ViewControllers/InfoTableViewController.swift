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
        case DeviceToken
        case InternalId
        
		var text: String {
            switch self {
            case DeviceToken: return "APNs Device token: "
            case InternalId: return "Internal Registration Id: "
            }
        }
        
        static let count: Int = {
            var max: Int = 0
            while let _ = SettingsCell(rawValue: max) { max += 1 }
            return max
        }()
    }
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(CopyableCell.self, forCellReuseIdentifier: kSettingCellId)
		tableView.estimatedRowHeight = 44
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(InfoTableViewController.registrationChanged), name: MMNotificationRegistrationUpdated, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(InfoTableViewController.registrationChanged), name: MMNotificationDeviceTokenReceived, object: nil)
    }
    
    @IBAction func closeButtonClicked(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: Notification
	func registrationChanged() {
		tableView.reloadData()
	}
	
    //MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
    }
	
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return SettingsCell.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsCell(rawValue: section)?.text
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kSettingCellId, forIndexPath: indexPath)
        cell.textLabel?.numberOfLines = 0
		
		var settingValue : String?
		switch indexPath.section {
		case SettingsCell.DeviceToken.rawValue:
			settingValue = MobileMessaging.currentInstallation?.deviceToken
		case SettingsCell.InternalId.rawValue:
			settingValue = MobileMessaging.currentInstallation?.internalId
		default: break
		}
		
		cell.textLabel?.text = settingValue
        return cell
    }
}