//
//  CPChatVC.swift
//
//  Created by Andrey K. on 24.07.15.
//

import UIKit

open class CPChatVC: CPUserDataVC, CPUserDataProtocol, ChatSettingsApplicable, ChatMessagesControllerDelegate, UIGestureRecognizerDelegate
{
	func applySettings() {
        guard let settings = MobileMessaging.mobileChat?.settings else {
            return
        }
		composeBarView.buttonTintColor = settings.tintColor
		title = settings.title
	}
	
	lazy var composeBarDelegate = CPComposeBarDelegate(tableView: self.tableView, makeMessageBlock: { [weak self] text in
		self?.createTextMessage(text)
	})
	
	lazy var selectedMessages = Set<SelectedMessageMeta>()
	
	lazy var editBtn: CPBarButtonItem! = {
		let ret = CPBarButtonItem(actionBlock: { [weak self] _ in
			self?.switchTableViewEditing(animated: true)
		})
		ret.title = "Edit" //TODO: translate for localization
		return ret
    }()
	
	lazy var dismissBtn: CPBarButtonItem! = {
		let ret = CPBarButtonItem(actionBlock: { [weak self] _ in
			self?.dismiss(animated: true)
		})
		ret.title = MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel")
		return ret
    }()
	
	lazy var editingToolbar: CPEditingToolbar! = {
		return CPEditingToolbar(markAsReadBtn: CPBarButtonItem(actionBlock: { [weak self] _ in self?.markAsRead() }), deleteBtn: CPBarButtonItem(actionBlock: {[weak self]  _ in  self?.deleteMessages() }))
    }()
	
	var titleView: UILabel?
	var scrollingRecognizer: UIPanGestureRecognizer!
	var lastComposingStateSentDateTime: TimeInterval = Date().timeIntervalSinceReferenceDate
	fileprivate var isVeryFirstRefetch: Bool = true
	fileprivate var isScrollToBottomNeeded: Bool = false
	fileprivate var isScrollToBottomEnabled: Bool = true
	
	var composeBarView: ComposeBar!
	var docImportMenu: UIDocumentMenuViewController!
	var documentAction = UIDocumentInteractionController()
	var chatMessageCountUpdatedBlock: ((_ count: Int, _ unread: Int) -> Void)?
	
	override init() {
		super.init()
		tableViewStyle = .plain
	}
	
	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	deinit {
		tableView?.delegate = nil
		tableView?.dataSource = nil
		composeBarView?.delegate = nil
	}
	
	var chatMessagesController: ChatMessagesController?
	
	var lastIndexPath: IndexPath?
	
	override open func viewDidLoad() {
		super.viewDidLoad()
		chatMessagesController = MobileMessaging.mobileChat?.chatMessagesController
		chatMessagesController?.delegate = self
		
		scrollingRecognizer = UIPanGestureRecognizer(target: self, action: #selector(CPChatVC.handlePanning))
		scrollingRecognizer.delegate = self
		
		NotificationCenter.default.addObserver(self, selector: #selector(CPChatVC.applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		
		setupUI()
		setupBadge()
		dismissKeyboardIfViewTapped(self.tableView)
		registerToChatSettingsChanges()
	}
	
	//Don't want to show badge if we are on Chat screen, because of blinking when new message arrives
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if isVeryFirstRefetch {
			chatMessagesController?.performFetch()
            tableView.reloadData()
			if let chatNC = navigationController as? CPChatNavigationVC, chatNC.isModal {
				navigationItem.leftBarButtonItem = dismissBtn
			}
		}
	}
	
	override open func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		setAllVisibleMessagesAsSeen()
	}
	
    @objc func applicationDidBecomeActive() {
		setAllVisibleMessagesAsSeen()
	}

	func setAllVisibleMessagesAsSeen() {
		guard isVisible else {
			return
		}
		
		let mids = (tableView.visibleCells as? [CPMessageCell] ?? []).compactMap({ $0.message }).filter({ $0.isYours == false && $0.isSeen == false }).map({ $0.id })
		if !mids.isEmpty {
			MobileMessaging.mobileChat?.markMessagesSeen(messageIds: mids, completion: nil)
		}
	}
	
	override open func viewWillDisappear(_ animated: Bool) {
		composeBarView.resignFirstResponder()
		super.viewWillDisappear(animated)
	}
	
	override open func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		scrollToBottomIfNeeded()
	}
	
	//MARK: content
	public func controllerWillChangeContent(_ controller: ChatMessagesController) {
		tableView.beginUpdates()
	}
	
	var insertHappened: Bool = false
	public func controller(_ controller: ChatMessagesController, didChange message: ChatMessage, at indexPath: IndexPath?, for type: ChatMessagesChangeType, newIndexPath: IndexPath?) {
		
		switch type {
		case .insert:
			guard let newIndexPath = newIndexPath else {
				return
			}
			insertHappened = true
			tableView.insertRows(at: [newIndexPath], with: UITableViewRowAnimation.bottom)
			isScrollToBottomNeeded = true
			lastIndexPath = newIndexPath
		case .update:
			if let indexPath = indexPath, let messageCell = tableView.cellForRow(at: indexPath) as? CPMessageCell {
				configureCell(messageCell, atIndexPath: indexPath, withExplicitMessage: message)
			}
		case .move:
			if let indexPath = indexPath, let newIndexPath = newIndexPath {
				if indexPath == newIndexPath {
					if let messageCell = tableView.cellForRow(at: indexPath) as? CPMessageCell {
						configureCell(messageCell, atIndexPath: indexPath)
					}
				} else {
					tableView.moveRow(at: indexPath, to: newIndexPath)
				}
			}
		case .delete:
			if let indexPath = indexPath {
				tableView.deleteRows(at: [indexPath], with: .automatic)
			}
		}
	}
	
	public func controllerDidChangeContent(_ controller: ChatMessagesController) {
		tableView.endUpdates()
		if UIApplication.shared.applicationState == UIApplicationState.active {
			let visibleTableViewAreaHeight = (tableView.cp_y + tableView.contentInset.top + composeBarView.cp_y - tableView.contentInset.bottom)
			isScrollToBottomNeeded = isScrollToBottomEnabled && isScrollToBottomNeeded && tableView.contentSize.height > visibleTableViewAreaHeight

			if isScrollToBottomNeeded {
				isScrollToBottomNeeded = false
				if let indexPath = lastIndexPath {
					tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
					lastIndexPath = nil
				}
			}
			if insertHappened {
				insertHappened = false
				setAllVisibleMessagesAsSeen()
			}
		}
		updateEditBtnAvailability()
	}
		
	func configureCell(_ cell: CPMessageCell, atIndexPath indexPath: IndexPath, withExplicitMessage message: ChatMessage? = nil) {
		let messageToSet: ChatMessage?
		if message != nil {
			messageToSet = message
		} else {
			messageToSet = chatMessagesController?.chatMessage(at: indexPath)
		}
		
		guard messageToSet != nil else {
			return
		}
		
		cell.message = messageToSet
		cell.highlightMessagesAsNotSeen(isViewVisible: self.isVisible)
	}
	
	func setupBadge() {
		let tabbaritem: UITabBarItem
		if let nc = self.navigationController as? CPChatNavigationVC {
			tabbaritem = nc.tabBarItem
		} else {
			tabbaritem = self.tabBarItem
		}
		MobileMessaging.mobileChat?.defaultChatStorage?.messagesCountersUpdateHandler = { total, notseen in
			if !self.isVisible || notseen == 0 {
				tabbaritem.badgeValue = notseen > 0 ? "\(notseen)" : nil
				if #available(iOS 10.0, *) {
					tabbaritem.badgeColor = UIColor.MAIN()
				}
			}
		}
	}
	
	func setupUI() {
		view.backgroundColor = UIColor(white: 0.95, alpha: 1)
		tableView.allowsMultipleSelectionDuringEditing = true
		tableView.backgroundColor = UIColor(white: 0.95, alpha: 1)
		tableView.separatorStyle = UITableViewCellSeparatorStyle.none
		tableView.addGestureRecognizer(scrollingRecognizer)
		tableView.allowsMultipleSelectionDuringEditing = true
		navigationItem.rightBarButtonItem = editBtn
		setupComposerBar()
	}
	
	//MARK: keyboard
	override func keyboardWillShow(_ duration: TimeInterval, curve: UIViewAnimationCurve, options: UIViewAnimationOptions, height: CGFloat) {
		super.keyboardWillShow(duration, curve: curve, options: options, height: height)
		UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
			self.composeBarView.frame.y = self.view.frame.height - height - self.composeBarView.frame.height
		}, completion: nil)
	}
	
	override func keyboardWillHide(_ duration: TimeInterval, curve: UIViewAnimationCurve, options: UIViewAnimationOptions, height: CGFloat) {
		super.keyboardWillHide(duration, curve: curve, options: options, height: height)
		let block = {
			self.composeBarView.frame.y = self.view.frame.height - self.composeBarView.frame.height
		}
		UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
	}
	
	//MARK: gestures
    @objc func handlePanning() {
		composeBarView.resignFirstResponder()
	}
	
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
			let velocity = gestureRecognizer.velocity(in: self.tableView)
			let result = velocity.y > 200 && fabs(velocity.y) > fabs(velocity.x)
			return result
		}
		return false
	}
	
	//MARK: scrolling
	func scrollToBottomIfNeeded() {
		let scrolledFromBottom = fabsf(Float(tableView.contentOffset.y + tableView.bounds.height - tableView.contentSize.height - tableView.contentInset.bottom))
		let doStickToBottom = scrolledFromBottom < 20
		if doStickToBottom || isVeryFirstRefetch {
			isVeryFirstRefetch = false
			if tableView.contentSize.height > tableView.frame.size.height {
				let offset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.frame.size.height + tableView.contentInset.bottom)
				tableView.contentOffset = offset
			}
		}
	}
	
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		isScrollToBottomEnabled = false
		invalidateScrollingTimer()
	}
	
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if !decelerate {
			resolveScrollingEnabled()
		}
	}
	
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		resolveScrollingEnabled()
	}
	
	func resolveScrollingEnabled() {
		invalidateScrollingTimer()
		let scrolledFromBottom = fabsf(Float(tableView.contentOffset.y + tableView.bounds.height - tableView.contentSize.height - tableView.contentInset.bottom))
		isScrollToBottomEnabled = scrolledFromBottom < 20
		
		if !isScrollToBottomEnabled {
			timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(CPChatVC.resetAutoScrollingEnabled), userInfo: nil, repeats: false)
		}
	}
	
    @objc func resetAutoScrollingEnabled() {
		if !isScrollToBottomEnabled {
			isScrollToBottomEnabled = true
		}
	}
	
	func invalidateScrollingTimer() {
		if timer.isValid {
			timer.invalidate()
		}
	}
	
	var timer = Timer()
}

extension CPChatVC {
//MARK: Editing utils
	func deleteMessages() {
		let completion = {
			self.switchTableViewEditing(animated: true)
		}
		
		if !selectedMessages.isEmpty {
			MobileMessaging.mobileChat?.defaultChatStorage?.remove(withIds: selectedMessages.map({ $0.messageId }), completion: { _ in
				completion()
			})
		} else {
			let actionDelete = UIAlertAction(title: "Delete", style: .destructive) { (action) in
				MobileMessaging.mobileChat?.defaultChatStorage?.removeAllMessages(completion: { _ in
					completion()
				})
			}
			let actionCancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
			let alert = UIAlertController(title: nil, message: "Are you sure you want to delete all messages?", preferredStyle: .actionSheet)
			alert.addAction(actionDelete)
			alert.addAction(actionCancel)
			present(alert, animated: true, completion: nil)
		}
	}
	
	func markAsRead() {
		if !selectedMessages.isEmpty {
			MobileMessaging.mobileChat?.markMessagesSeen(messageIds: selectedMessages.filter({ $0.isSeen == false }).map({ $0.messageId }), completion: nil)
		} else {
			MobileMessaging.mobileChat?.markAllMessagesSeen()
		}
		switchTableViewEditing(animated: true)
	}
	
	func setEditingToolbarVisible(visible: Bool, animated: Bool) {
		if visible {
			editingToolbar.frame = composeBarView.frame
		}
		if !editingToolbar.isDescendant(of: view) {
			view.addSubview(self.editingToolbar)
			editingToolbar.layer.opacity = 0
		}
		let duration: TimeInterval = (animated ? 0.3 : 0.0)
		UIView.animate(withDuration: duration,
		               delay: 0.0,
		               options: UIViewAnimationOptions.curveLinear,
		               animations: { [weak self] () -> Void in
						self?.editingToolbar.layer.opacity = visible ? 1 : 0
		})
	}

	func switchTableViewEditing(animated: Bool) {
		selectedMessages.removeAll()
		updateEditingModeButtons()
		tableView.setEditing(!tableView.isEditing, animated: animated)
		composeBarView.resignFirstResponder()
		setEditingToolbarVisible(visible: tableView.isEditing, animated: animated)
		editBtn.title = tableView.isEditing ? "Cancel" : "Edit"
	}

	func updateEditingModeButtons() {
		let cnt = selectedMessages.count
		let isEmpty = cnt == 0
		editingToolbar.deleteBtn.title = isEmpty ? "Delete all" : "Delete (\(cnt))"
		editingToolbar.markAsReadBtn.title = isEmpty ? "Mark all as read" : "Mark as read (\(cnt))"
	}

	func updateEditBtnAvailability() {
		editBtn.isEnabled = !tableView.visibleCells.isEmpty || tableView.isEditing
	}
}
