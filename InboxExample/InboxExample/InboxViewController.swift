//
//  InboxViewController.swift
//  InboxExample
//
//  Created by Andrey Kadochnikov on 25.05.2022.
//

import Foundation
import UIKit
import MobileMessaging

enum SupportedTopics: String, CaseIterable {
    case all = "All"
    case notifications = "Notifications"
    case promo = "Promo"
    
    func topicId() -> String? {
        switch self {
        case .all: return nil
        case .notifications: return "notifications"
        case .promo: return "promo"
        }
    }
}

class InboxViewController: UITableViewController {
    @IBOutlet weak var messagesCountsInfo: UIBarButtonItem!
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    fileprivate var messages: [MM_MTMessage] = []
    
    fileprivate var countTotal: Int = 0 {
        didSet {
            self.messagesCountsInfo.title = "\(countTotal) messages, \(countUnread) unread"
            self.postCountersUpdatedNotificationIfNeeded(countTotal: countTotal, countUnread: countUnread)
        }
    }
    
    fileprivate var countUnread: Int = 0 {
        didSet {
            self.messagesCountsInfo.title = "\(countTotal) messages, \(countUnread) unread"
            self.postCountersUpdatedNotificationIfNeeded(countTotal: countTotal, countUnread: countUnread)
        }
    }
    
    fileprivate var currentTopicId: String? {
        return SupportedTopics.allCases[segmentedControl.selectedSegmentIndex].topicId()
    }
    
    @IBAction func loadOlder(_ sender: Any) {
        let lastMessageDate = messages.last?.sendDateTime
        let toDateTime = lastMessageDate == nil ? nil : Date.init(timeIntervalSince1970: lastMessageDate!)
        if let externalUserId = MobileMessaging.getUser()?.externalUserId {
            showActivityIndicator()
            let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: toDateTime, topic: currentTopicId, limit: nil)
            MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options, completion: { inbox, error in
                assert(Thread.isMainThread)
                if let inbox = inbox {
                    self.messages = self.messages + inbox.messages
                    self.countTotal = inbox.countTotal
                    self.countUnread = inbox.countUnread
                }
                
                self.tableView.reloadData()
                self.hideActivityIndicator(nil)
                self.showAlertIfErrorPresent(error)
            })
        }
    }
    
    @IBAction func topicDidChange(_ sender: UISegmentedControl) {
        fetchInboxWithActivityIndicator(fromDateTime: nil)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        if let externalUserId = MobileMessaging.getUser()?.externalUserId {
            fetchInbox(externalUserId, topic: SupportedTopics.allCases[segmentedControl.selectedSegmentIndex].topicId())
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        initTopicsSegmentedControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchInboxWithActivityIndicator(fromDateTime: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presentSetSeenDialog(message: messages[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "inboxMessageCell", for: indexPath)
        let message = messages[indexPath.row]
        cell.textLabel?.text = "Text: \(message.text ?? "n/a")"
        cell.detailTextLabel?.text = "Topic: \(message.topic ?? "n/a")"
        cell.textLabel?.textColor = message.seenStatus == .NotSeen ? UIColor.black : UIColor.lightGray
        cell.detailTextLabel?.textColor = message.seenStatus == .NotSeen ? UIColor.black : UIColor.lightGray
        return cell
    }
    
    fileprivate func fetchInboxWithActivityIndicator(fromDateTime: Date?) {
        if let externalUserId = MobileMessaging.getUser()?.externalUserId {
            showActivityIndicator()
            fetchInbox(externalUserId, topic: currentTopicId)
        }
    }
    
    fileprivate func initTopicsSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (index, topic) in SupportedTopics.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: topic.rawValue, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
    }
    
    fileprivate func fetchInbox(_ externalUserId: String, topic: String?) {
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: topic, limit: nil)
        MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options, completion: { inbox, error in
            assert(Thread.isMainThread)
            if let inbox = inbox {
                self.messages = inbox.messages
                self.countTotal = inbox.countTotal
                self.countUnread = inbox.countUnread
            }
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
            self.hideActivityIndicator(nil)
            self.showAlertIfErrorPresent(error)
        })
    }
    
    fileprivate func postCountersUpdatedNotificationIfNeeded(countTotal: Int, countUnread: Int) {
        NotificationCenter.default.post(name: NSNotification.Name.inboxCountersUpdated, object: nil, userInfo: [NotificationKeys.unreadCount: countUnread])
    }
    
    fileprivate func presentSetSeenDialog(message: MM_MTMessage) {
        if let externalUserId = MobileMessaging.getUser()?.externalUserId  {
            let alert = UIAlertController(title: "Mark as read", message: "Do you want to mark this message as read?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { ac in
                message.seenStatus = .SeenNotSent
                self.tableView.reloadData()
                self.showActivityIndicator()
                MobileMessaging.inbox?.setSeen(externalUserId: externalUserId, messageIds: [message.messageId], completion: { error in
                    assert(Thread.isMainThread)
                    self.hideActivityIndicator(nil)
                    self.showAlertIfErrorPresent(error)
                    if error == nil {
                        self.decrementUnreadCount()
                    }
                })
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    fileprivate func decrementUnreadCount() {
        countUnread = countUnread - 1
    }
}
