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

extension UIColor {
	class func enabledCellColor() -> UIColor {
		return UIColor.white
	}
	class func disabledCellColor() -> UIColor {
		return UIColor.TABLEVIEW_GRAY().lighter(2)
	}
	
	func darker(_ percents: CGFloat) -> UIColor {
		let color = UIColor.purple
		var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
		self.getRed(&r, green: &g, blue: &b, alpha: &a)
		func reduce(_ value: CGFloat) -> CGFloat {
			let result: CGFloat = max(0, value - value * (percents/100.0))
			return result
		}
		return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
	}
	
	func lighter(_ percents: CGFloat) -> UIColor {
		let color = UIColor.purple
		var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
		self.getRed(&r, green: &g, blue: &b, alpha: &a)
		func reduce(_ value: CGFloat) -> CGFloat {
			let result: CGFloat = min(1, value + value * (percents/100.0))
			return result
		}
		return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
	}
	class func colorMod255(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
		return UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
	}
	class func TEXT_BLACK() -> UIColor {
		return UIColor.colorMod255(65, 65, 65)
	}
	class func TEXT_GRAY() -> UIColor {
		return UIColor.colorMod255(165, 165, 165)
	}
	class func TABBAR_TITLE_BLACK() -> UIColor {
		return UIColor.colorMod255(90, 90, 90)
	}
	class func ACTIVE_TINT() -> UIColor {
		return UIColor.MAIN()
	}
	class func TABLEVIEW_GRAY() -> UIColor {
		return UIColor.colorMod255(239, 239, 244)
	}
	class func MAIN() -> UIColor {
		#if IO
            return UIColor.colorMod255(234, 55, 203)
		#else
			return UIColor.colorMod255(239, 135, 51)
		#endif
	}
	class func MAIN_MED_DARK() -> UIColor {
		return UIColor.MAIN().darker(25)
	}
	class func MAIN_DARK() -> UIColor {
		return UIColor.MAIN().darker(50)
	}
	class func CHAT_MESSAGE_COLOR(_ isYours: Bool) -> UIColor {
		if (isYours == true) {
			return UIColor.colorMod255(253, 242, 229)
		} else {
			return UIColor.white
		}
	}
	class func CHAT_MESSAGE_FONT_COLOR(_ isYours: Bool) -> UIColor {
		if (isYours == true) {
			return UIColor.colorMod255(73, 158, 90)
		} else {
			return UIColor.darkGray
		}
	}
	class func TABLE_SEPARATOR_COLOR() -> UIColor {
		return UIColor.colorMod255(210, 209, 213)
	}
	class func GREEN() -> UIColor {
		return UIColor.colorMod255(127, 211, 33)
	}
	class func RED() -> UIColor {
		return UIColor.colorMod255(243, 27, 0)
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
			alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: dismissActionHandler))
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
	var hashValue: Int {
		return messageId.hashValue
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
