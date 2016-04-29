//
//  SettingsTableViewController.swift
//  MobileMessaging
//
//  Created by okoroleva on 05.04.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
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
		messagingInfo.removeObserver(self, forKeyPath: "deviceToken")
		messagingInfo.removeObserver(self, forKeyPath: "internalId")
	}
	
	var messagingInfo: MessagingInfo {
		return MessagingInfoManager.sharedInstance.messagingInfo
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerClass(CopyableCell.self, forCellReuseIdentifier: kSettingCellId)
		tableView.estimatedRowHeight = 44
		messagingInfo.addObserver(self, forKeyPath: "deviceToken", options: .New, context: nil)
		messagingInfo.addObserver(self, forKeyPath: "internalId", options: .New, context: nil)
    }
    
    @IBAction func closeButtonClicked(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    //MARK: Notification
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == "deviceToken" || keyPath == "internalId" {
			tableView.reloadData()
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
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
			settingValue = messagingInfo.deviceToken
		case SettingsCell.InternalId.rawValue:
			settingValue = messagingInfo.internalId
		default: break
		}
		
		cell.textLabel?.text = settingValue
        return cell
    }
}