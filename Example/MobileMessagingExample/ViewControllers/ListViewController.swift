//
//  ViewController.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.
//

import UIKit
import MobileMessaging

let kMessageCellId = "kMessageCellId"
let kMessageDetailsSegueId = "kMessageDetailsSegueId"
let kInformationSegueId = "kInformationSegueId"
let kSettingsSegueId = "kSettingsSegueId"

class ListViewController: UIViewController, UITableViewDelegate {
	
	let messagesManager = MessagesManager.sharedInstance
    @IBOutlet weak var tableView: UITableView!
	@IBAction func trashInbox(_ sender: AnyObject) {
		MessagesManager.sharedInstance.cleanMessages()
		updateUI()
        
        // This is for testing WebInteractiveMessageAlertController
        /**
         Currently, for development and testing purposes we are serving local HTML files in our project for showing In-App-Notif
         This is only temporary, but for easier access and testability, InAppNotificationTempStaticResources directory is added inside the project so that anyone can run it locally with as few as possible steps
         The in-app can currently only show using an URL, it must be reachable over the internet, i.e. IP address.
         
         Since the feature itself will never show local HTML in production, we decided to instead of passing local HTML files to the app directly, to actually serve the local HTML files over a local http-server
         and then just pass the IP address as an URL to the In-App. It is a workaround since it would be too complex to try and setup everything locally with BundleResources when it is not a feature that is going to be live in production.
         
         How to actually test it then:
         1. Open terminal at InAppNotificationTempStaticResources directory.
         2. Run npx http-server
         3. Copy IP address (e.g. http://192.168.1.69:8080)
         4. Inside Consts.InAppDetailsKeys.url set path to the IP address and add suffix `/gif`, `/static` or `/video`if you want the In-App to be animated, static or a video.
         5. Customize position and type of In-App if you want, or leave the default values.
         6. Run the app.
         */
        
        showInApp(withUrl: "http://169.254.38.148:8080/static")
	}
    
    func showInApp(withUrl url: String) {
        MobileMessaging.didReceiveRemoteNotification(apnsInAppMessage(UUID().uuidString, url: url)) { result in }
    }
    
    func apnsInAppMessage(_ messageId: String, url: String) -> [AnyHashable: Any] {
        return [
            "messageId": messageId,
            "silent": true,
            "aps": ["alert": ["body": "msg_body"]],
            "internalData": [
                "inAppDetails": [
                    "url" : url,
                    "position": MMInAppMessagePosition.top.rawValue,
                    "type": MMInAppMessageType.banner.rawValue
                ]
            ]
        ]
    }
		
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(MessageCell.self, forCellReuseIdentifier: kMessageCellId)
		tableView.estimatedRowHeight = 44
		tableView.rowHeight = UITableView.automaticDimension
		tableView.dataSource = messagesManager
		
		messagesManager.newMessageBlock = { _ in
			self.updateUIWithInsertMessage()
		}
        updateUI()
	}
	
	//MARK: TableView delegate
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		performSegue(withIdentifier: kMessageDetailsSegueId, sender: indexPath)
	}
    
    //MARK: Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kMessageDetailsSegueId,
            let vc = segue.destination as? MessageDetailsViewController,
            let indexPath = sender as? IndexPath {
                vc.message = messagesManager.messages[indexPath.row]
        }
    }

    //MARK: Utils
    private func updateUIWithInsertMessage() {
        tableView.insertRows(at: [IndexPath(item: 0, section: 0)], with: .right)
        tableView.selectRow(at: IndexPath(item: 0, section: 0), animated: true, scrollPosition: .middle)
    }
    
    private func updateUI() {
        tableView.reloadData()
    }
}

