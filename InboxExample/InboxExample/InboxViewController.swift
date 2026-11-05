// 
//  InboxExample/InboxExample/InboxViewController.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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

/// Remembers successfully deleted inbox messages per user for the lifetime of the app process, so that it survives
/// re-opening the Inbox screen. A successful delete is not guaranteed to be visible in the very next fetch
/// (eventual consistency, with no guaranteed upper bound), so fetched messages are filtered through this store.
/// Limitation: after an app restart, a deleted message may reappear while the deletion is still propagating.
/// Accessed on the main thread only.
final class DeletedInboxMessages {
    static let shared = DeletedInboxMessages()
    /// Posted (on the main thread) when a deletion is recorded; `object` is the External User ID. Every visible Inbox screen reloads on it.
    static let didChangeNotification = Notification.Name("DeletedInboxMessagesDidChange")
    private var messageIdsByUser: [String: Set<String>] = [:]
    
    func record(_ messageId: String, externalUserId: String) {
        guard messageIdsByUser[externalUserId, default: []].insert(messageId).inserted else {
            return
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: externalUserId)
    }
    
    func messageIds(externalUserId: String) -> Set<String> {
        return messageIdsByUser[externalUserId] ?? []
    }
}

/// Server counters together with the messages returned in the same response. Only messages present in that response
/// are known to be included in its counters, so only those are used to correct the counters for deleted messages.
/// Message ids and their unread state are copied when the response is accepted, because `MM_MTMessage` objects are
/// mutable (e.g. marked as seen locally) and the snapshot must keep the state the server counted.
struct InboxCountersSnapshot {
    let sequence: Int
    let countTotal: Int
    let countUnread: Int
    let messageIds: Set<String>
    let unreadMessageIds: Set<String>
    
    init(sequence: Int, inbox: MMInbox) {
        self.sequence = sequence
        self.countTotal = inbox.countTotal
        self.countUnread = inbox.countUnread
        self.messageIds = Set(inbox.messages.map { $0.messageId })
        self.unreadMessageIds = Set(inbox.messages.filter { $0.seenStatus == .NotSeen }.map { $0.messageId })
    }
    
    func displayedCounters(excluding deletedIds: Set<String>) -> (total: Int, unread: Int) {
        let deletedInResponse = messageIds.intersection(deletedIds).count
        let deletedUnread = unreadMessageIds.intersection(deletedIds).count
        return (max(0, countTotal - deletedInResponse), max(0, countUnread - deletedUnread))
    }
}

class InboxViewController: UITableViewController {
    @IBOutlet weak var messagesCountsInfo: UIBarButtonItem!
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private static let pageSize = 20
    
    /// Incremented whenever pagination starts over (refresh, topic change). Responses of older generations are dropped.
    private var generation = 0
    /// Monotonic sequence of all fetch requests, used to keep only the newest counters snapshot.
    private var requestSequence = 0
    /// Sequence of the outstanding page request, if any.
    private var pageRequestSequence: Int?
    
    private var loadedMessages: [MM_MTMessage] = []
    private var nextCursor: String?
    private var countersSnapshot: InboxCountersSnapshot?
    
    private var externalUserId: String? {
        return MobileMessaging.getUser()?.externalUserId
    }
    
    private var currentTopicId: String? {
        return SupportedTopics.allCases[segmentedControl.selectedSegmentIndex].topicId()
    }
    
    private var messages: [MM_MTMessage] {
        guard let externalUserId = externalUserId else {
            return []
        }
        let deletedIds = DeletedInboxMessages.shared.messageIds(externalUserId: externalUserId)
        return loadedMessages.filter { !deletedIds.contains($0.messageId) }
    }
    
    @IBAction func loadOlder(_ sender: Any) {
        loadPage(startOver: false)
    }
    
    @IBAction func topicDidChange(_ sender: UISegmentedControl) {
        loadPage(startOver: true)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadPage(startOver: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        initTopicsSegmentedControl()
        // A delete may complete on another (e.g. already dismissed) Inbox screen; keep this table in sync with the shared store.
        NotificationCenter.default.addObserver(self, selector: #selector(deletedMessagesDidChange(_:)), name: DeletedInboxMessages.didChangeNotification, object: nil)
    }
    
    @objc private func deletedMessagesDidChange(_ notification: Notification) {
        guard let externalUserId = notification.object as? String, externalUserId == self.externalUserId else {
            return
        }
        render()
        refreshCounters()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPage(startOver: true)
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
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let externalUserId = externalUserId else {
            return
        }
        // Capture the identity of the deleted message, never the row index: the list may change before the request completes.
        deleteMessage(messages[indexPath.row].messageId, externalUserId: externalUserId)
    }
    
    // MARK: - Fetching
    
    /// Loads the first page (`startOver`) or the next page using the cursor returned by the previous page.
    private func loadPage(startOver: Bool) {
        guard let externalUserId = externalUserId else {
            return
        }
        if startOver {
            generation += 1
            loadedMessages = []
            nextCursor = nil
            countersSnapshot = nil
            render()
        } else if pageRequestSequence != nil || nextCursor == nil {
            // a page is already loading, or there are no older messages
            return
        }
        
        let generation = self.generation
        let sequence = nextRequestSequence()
        pageRequestSequence = sequence
        // The cursor must be used with the same topic and date filters as the page it was returned with.
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: currentTopicId, limit: Self.pageSize, cursor: startOver ? nil : nextCursor)
        showActivityIndicator()
        
        Task { @MainActor in
            do {
                let inbox = try await MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options)
                guard generation == self.generation else {
                    return // stale response of a previous topic/refresh
                }
                if self.pageRequestSequence == sequence {
                    self.pageRequestSequence = nil
                    self.loadedMessages += inbox?.messages ?? []
                    self.nextCursor = inbox?.nextCursor
                }
                if let inbox = inbox {
                    self.acceptCountersSnapshot(inbox, sequence: sequence)
                }
                self.finishLoading()
            } catch {
                guard generation == self.generation else {
                    return
                }
                if self.pageRequestSequence == sequence {
                    self.pageRequestSequence = nil
                }
                self.finishLoading()
                self.showAlertIfErrorPresent(error as NSError)
            }
        }
    }
    
    /// Fetches the first page only to get fresh counters. Loaded pages and the pagination cursor are not touched.
    private func refreshCounters() {
        guard let externalUserId = externalUserId else {
            return
        }
        let generation = self.generation
        let sequence = nextRequestSequence()
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: currentTopicId, limit: Self.pageSize, cursor: nil)
        
        Task { @MainActor in
            guard let inbox = try? await MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: options),
                  generation == self.generation else {
                return
            }
            self.acceptCountersSnapshot(inbox, sequence: sequence)
            self.render()
        }
    }
    
    private func nextRequestSequence() -> Int {
        requestSequence += 1
        return requestSequence
    }
    
    private func acceptCountersSnapshot(_ inbox: MMInbox, sequence: Int) {
        if sequence > (countersSnapshot?.sequence ?? 0) {
            countersSnapshot = InboxCountersSnapshot(sequence: sequence, inbox: inbox)
        }
    }
    
    private func finishLoading() {
        refreshControl?.endRefreshing()
        hideActivityIndicator(nil)
        render()
    }
    
    private func render() {
        tableView.reloadData()
        guard let externalUserId = externalUserId, let snapshot = countersSnapshot else {
            messagesCountsInfo.title = nil
            return
        }
        // Counters are always derived from the latest server snapshot, never decremented locally.
        let counters = snapshot.displayedCounters(excluding: DeletedInboxMessages.shared.messageIds(externalUserId: externalUserId))
        messagesCountsInfo.title = "\(counters.total) messages, \(counters.unread) unread"
        postCountersUpdatedNotification(countUnread: counters.unread)
    }
    
    // MARK: - Deleting
    
    private func deleteMessage(_ messageId: String, externalUserId: String) {
        showActivityIndicator()
        Task { @MainActor in
            do {
                // MobileMessaging.inbox is nil when the SDK is not started; optional chaining would then skip the call
                // without an error, so check it explicitly instead of treating "nothing happened" as a successful delete.
                guard let inbox = MobileMessaging.inbox else {
                    throw NSError(type: .MobileMessagingInstanceNotInitialized)
                }
                // Uses Application Code authorization like the fetch in this example. In production use
                // deleteMessages(token:externalUserId:messageIds:) with the same JWT used for fetching the inbox.
                try await inbox.deleteMessages(externalUserId: externalUserId, messageIds: [messageId])
                self.hideActivityIndicator(nil)
                // Recorded even if the screen, topic or user changed meanwhile, so the deletion is never forgotten.
                // Recording notifies every visible Inbox screen of this user, including this one, to reload.
                DeletedInboxMessages.shared.record(messageId, externalUserId: externalUserId)
            } catch {
                self.hideActivityIndicator(nil)
                guard externalUserId == self.externalUserId else {
                    return
                }
                self.showAlertIfErrorPresent(error as NSError)
            }
        }
    }
    
    // MARK: - Helpers
    
    fileprivate func initTopicsSegmentedControl() {
        segmentedControl.removeAllSegments()
        for (index, topic) in SupportedTopics.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: topic.rawValue, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
    }
    
    fileprivate func postCountersUpdatedNotification(countUnread: Int) {
        NotificationCenter.default.post(name: NSNotification.Name.inboxCountersUpdated, object: nil, userInfo: [NotificationKeys.unreadCount: countUnread])
    }
    
    fileprivate func presentSetSeenDialog(message: MM_MTMessage) {
        if let externalUserId = externalUserId {
            let alert = UIAlertController(title: "Mark as read", message: "Do you want to mark this message as read?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { ac in
                message.seenStatus = .SeenNotSent
                self.tableView.reloadData()
                self.showActivityIndicator()
                Task { @MainActor in
                    do {
                        try await MobileMessaging.inbox?.setSeen(externalUserId: externalUserId, messageIds: [message.messageId])
                        self.hideActivityIndicator(nil)
                        self.refreshCounters()
                    } catch {
                        self.hideActivityIndicator(nil)
                        self.showAlertIfErrorPresent(error as NSError)
                    }
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
