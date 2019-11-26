//
//  CPUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/06/16.
//
import UIKit
import CoreData

extension NSFetchedResultsController where ResultType == Message {
	func messageAt(_ indexPath: IndexPath) -> ChatMessage? {
		let storedmessage = self.object(at: indexPath)
		let msg = ChatMessage(message: storedmessage)
		return msg
	}
	
	var chatMessages: [ChatMessage] {
		return self.fetchedObjects?.compactMap({ storedmessage in
			return ChatMessage(message: storedmessage)
		}) ?? []
	}
}


public enum CPMessageDeliveryStatus: Int32 {
	case pendingSending = 0, pendingFileUploading, sent, delivered, failed
	
	public var name: String {
		switch self {
		case .pendingSending:
			return "Sending"
		case .pendingFileUploading:
			return "PendingFileUploading"
		case .sent:
			return "Sent"
		case .delivered:
			return "Delivered"
		case .failed:
			return "Failed"
		}
	}
}

extension MOMessageSentStatus {
	var deliveryStatus: CPMessageDeliveryStatus {
		switch self {
		case .SentSuccessfully:
			return CPMessageDeliveryStatus.sent
		case .SentWithFailure:
			return CPMessageDeliveryStatus.failed
		case .Undefined:
			return CPMessageDeliveryStatus.pendingSending
		}
	}
}


extension UIViewController {
	func dismissKeyboardIfViewTapped(_ tappedView: UIView) {
		let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
		tap.cancelsTouchesInView = false
		tappedView.addGestureRecognizer(tap)
	}
	
    @objc func dismissKeyboard() {
		view.endEditing(true)
	}
}

protocol ChatSettingsApplicable: NSObjectProtocol {
	func applySettings()
	func registerToChatSettingsChanges()
}

extension ChatSettingsApplicable where Self: NSObject {
	func registerToChatSettingsChanges() {
		ChatSettingsManager.sharedInstance.register(object: self)
		applySettings()
	}
}

extension CGSize {
	mutating func fitSize(_ maxSize: CGSize) -> CGSize {
		if (self.width < 1){
			self.width = 1
		}
		if (self.height < 1){
			self.height = 1
		}
		
		if (self.width > maxSize.width)
		{
			self.height = CGFloat(floorf(Float(self.height * maxSize.width / self.width)))
			self.width = maxSize.width
		}
		if (self.height > maxSize.height)
		{
			self.width = CGFloat(floorf(Float(self.width * maxSize.height / self.height)))
			self.height = maxSize.height
		}
		return self
	}
}

extension CGRect {
	var width: CGFloat {
		set {
			self.size.width = newValue
		}
		get {
			return self.size.width
		}
	}
	var height: CGFloat {
		set {
			self.size.height = newValue
		}
		get {
			return self.size.height
		}
	}
	var x: CGFloat {
		set {
			self.origin.x = newValue
		}
		get {
			return self.origin.x
		}
	}
	var y: CGFloat {
		set {
			self.origin.y = newValue
		}
		get {
			return self.origin.y
		}
	}
}

struct NSDateStaticFormatters {
	static var ISO8601SecondsFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return result
	}()
	static var CoreDataDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		return result
	}()
	static var timeFormatter: DateFormatter = {
		let result = DateFormatter()
		result.dateStyle = DateFormatter.Style.none
		result.timeStyle = DateFormatter.Style.short
		return result
	}()
}

enum NSDateUtilsErrors: Error {
	case convertatonError
}

extension Date {
	
	static func coreDataDateToString(_ date: Date) -> String {
		return NSDateStaticFormatters.CoreDataDateFormatter.string(from: date)
	}
	
	static func coreDataDateStringToDate(_ dateString: String) throws -> Date {
		if let result = NSDateStaticFormatters.CoreDataDateFormatter.date(from: dateString) {
			return result
		} else {
			throw NSDateUtilsErrors.convertatonError
		}
	}
	
	func toMediumDateTimeString() -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = DateFormatter.Style.medium
		formatter.timeStyle = DateFormatter.Style.short
		return formatter.string(from: self)
	}
	
	func toShortDateTimeString() -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = DateFormatter.Style.short
		formatter.timeStyle = DateFormatter.Style.short
		return formatter.string(from: self)
	}
	
	func toLongDateString() -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = DateFormatter.Style.long
		formatter.timeStyle = DateFormatter.Style.none
		return formatter.string(from: self)
	}
	
	func toMediumDateString() -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = DateFormatter.Style.medium
		formatter.timeStyle = DateFormatter.Style.none
		return formatter.string(from: self)
	}
	
	func timeString() -> String {
		return NSDateStaticFormatters.timeFormatter.string(from: self)
	}
	
	func toAgoTimeString() -> String {
		let formatter = DateFormatter()
		// если меньше 24 часов
		let diffSec = Int(Date().timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate)
		let day: Int = 60*60*24
		switch diffSec {
		case 0...day:
			formatter.timeStyle = DateFormatter.Style.short
			formatter.dateStyle = DateFormatter.Style.none
			return formatter.string(from: self)
		case day...day*7:
			let dateComponentsString = "hh:mm EE"
			if let format = DateFormatter.dateFormat(fromTemplate: dateComponentsString, options: 0, locale: Locale.current) {
				formatter.dateFormat = format
				return formatter.string(from: self)
			}
		default:
			formatter.dateStyle = DateFormatter.Style.short
			formatter.timeStyle = DateFormatter.Style.short
			return formatter.string(from: self)
		}
		return ""
	}
}

extension UIView {
	var cp_h: CGFloat {
		return self.bounds.size.height
	}
	var cp_w: CGFloat {
		return self.bounds.size.width
	}
	var cp_x: CGFloat {
		return self.frame.origin.x
	}
	var cp_y: CGFloat {
		return self.frame.origin.y
	}
}

func showAlertInRootVC(_ error: NSError) {
	UIApplication.shared.keyWindow!.rootViewController?.showAlert(error)
}

func showAlertInRootVC(_ title: String, message: String) {
	UIApplication.shared.keyWindow!.rootViewController?.showAlert(title, message: message)
}

extension UIViewController {
	var isVisible: Bool {
		return self.isViewLoaded && self.view.window != nil
	}
	func showAlert(_ title: String, message: String, dismissActionHandler: ((UIAlertAction) -> Swift.Void)? = nil) {
		DispatchQueue.main.async {
			let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel"), style: .cancel, handler: dismissActionHandler))
			self.present(alert, animated: true, completion: nil)
		}
	}
	func showAlert(_ error: Error?) {
		guard let error = error else {
			return
		}
		self.showAlert("Error", message: error.localizedDescription)
	}
}

func ==(l: SelectedMessageMeta, r: SelectedMessageMeta) -> Bool {
	return l.messageId == r.messageId
}
struct SelectedMessageMeta: Hashable {
	let isSeen: Bool
	let messageId: String
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(messageId)
	}

	init(_ msg: ChatMessage) {
		isSeen = msg.isSeen
		messageId = msg.id
	}
}

extension Message {
	var seenStatus: MMSeenStatus {
		return MMSeenStatus(rawValue: seenStatusValue) ?? .NotSeen
	}
}

extension ChatMessage {
	var isSeen: Bool {
		return seenStatus != .NotSeen
	}
}

class Weak<T: AnyObject> {
	weak var value : T?
	init (value: T) {
		self.value = value
	}
}
