// 
//  Example/MobileMessagingExample/ViewControllers/ListViewController.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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

