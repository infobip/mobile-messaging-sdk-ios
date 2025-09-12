//
//  SettingsTableViewController.swift
//  MobileMessaging
//
//  Created by okoroleva on 05.04.16.
//

import UIKit
@testable import MobileMessaging

let kSettingCellId = "kSettingCellId"

class InfoTableViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    enum SettingsCell: Int {
        case applicationCode
        case deviceToken
        case internalId
        
		var text: String {
            switch self {
            case .applicationCode: return "Application Code: "
            case .deviceToken: return "APNs Device token: "
            case .internalId: return "Push Registration Id: "
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
    @objc func registrationChanged() {
		tableView.reloadData()
	}
	
    //MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
    }
	
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsCell.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerText = SettingsCell(rawValue: section)?.text else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        
        let label = UILabel()
        label.text = headerText
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        if #available(iOS 13.0, *) {
            label.textColor = UIColor.systemGray
        } else {
            label.textColor = UIColor.darkGray
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -6)
        ])
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 28.0 // Standard grouped table view header height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kSettingCellId, for: indexPath)
        cell.textLabel?.numberOfLines = 0
		
		var settingValue : String?
		switch indexPath.section {
		case SettingsCell.applicationCode.rawValue:
			settingValue = MobileMessaging.sharedInstance?.applicationCode
		case SettingsCell.deviceToken.rawValue:
			settingValue = MobileMessaging.sharedInstance?.currentInstallation().pushServiceToken
		case SettingsCell.internalId.rawValue:
			settingValue = MobileMessaging.sharedInstance?.currentInstallation().pushRegistrationId
		default: break
		}
		
		cell.textLabel?.text = settingValue
        return cell
    }
}
