//
//  ViewController.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.
//

import UIKit
import Freddy

let kMessageCellId = "kMessageCellId"
let kMessageDetailsSegueId = "kMessageDetailsSegueId"
let kInformationSegueId = "kInformationSegueId"
let kSettingsSegueId = "kSettingsSegueId"

class ListViewController: UIViewController, UITableViewDelegate {
	
	let messagesManager = MessagesManager.sharedInstance
    @IBOutlet weak var tableView: UITableView!
	@IBAction func trashInbox(sender: AnyObject) {
		MessagesManager.sharedInstance.cleanMessages()
		updateUI()
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerClass(MessageCell.self, forCellReuseIdentifier: kMessageCellId)
		tableView.estimatedRowHeight = 44
		tableView.rowHeight = UITableViewAutomaticDimension;
		tableView.dataSource = messagesManager
		
		messagesManager.newMessageBlock = { _ in
			self.updateUIWithInsertMessage()
		}
        updateUI()
	}
	
	//MARK: TableView delegate
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		performSegueWithIdentifier(kMessageDetailsSegueId, sender: indexPath)
	}
    
    //MARK: Segues
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == kMessageDetailsSegueId,
            let vc = segue.destinationViewController as? MessageDetailsViewController,
            let indexPath = sender as? NSIndexPath {
                vc.message = messagesManager.messages[indexPath.row]
        }
    }

    //MARK: Utils
    private func updateUIWithInsertMessage() {
        tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)], withRowAnimation: .Right)
        tableView.selectRowAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: true, scrollPosition: .Middle)
    }
    
    private func updateUI() {
        tableView.reloadData()
    }
}

