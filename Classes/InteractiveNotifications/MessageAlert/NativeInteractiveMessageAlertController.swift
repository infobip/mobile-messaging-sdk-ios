import UIKit

protocol NativeInteractiveMessageAlertControllerDelegate: AnyObject {
    func nativeInteractiveMessageAlertControllerDidDismissWithAction(_ action: MMNotificationAction, categoryId: String?);
}

/// Shows an old-style in-app message using an interface composed of native views.
class NativeInteractiveMessageAlertController: UIViewController {
	private static let buttonHeight : CGFloat = 50
	private static let alertWidth : CGFloat = 270
	private static let maxImageHeight : CGFloat = 180
	private static let tapOutsideToDismissEnabled = true

	
	@IBOutlet weak var alertMaskBackground: UIImageView!
	@IBOutlet weak var shadowView: UIView!
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var imageView: LoadingImageView!
	@IBOutlet weak var headerViewHeightConstraint: NSLayoutConstraint!
	@IBOutlet weak var alertTitle: UILabel!
	@IBOutlet weak var alertText: UILabel!
	@IBOutlet weak var alertActionStackView: UIStackView!
	@IBOutlet weak var alertStackViewHeightConstraint: NSLayoutConstraint!
	@IBOutlet weak var titleAndMessageSpace: NSLayoutConstraint!
	
	private let titleText: String?
	private let messageText: String
	private let imageURL: URL?
	private let image: Image?
    private let categoryId: String?
	private var buttons: [InteractiveMessageButton]!
    unowned var delegate: NativeInteractiveMessageAlertControllerDelegate?
	
	init(titleText: String?,
         messageText: String,
         imageURL: URL?,
         image: Image?,
         dismissTitle: String?,
         openTitle: String?) {
		self.titleText = titleText
		self.messageText = messageText
		self.imageURL = imageURL
		self.image = image
        self.categoryId = nil
		
        super.init(nibName: "NativeInteractiveMessageAlertController", bundle: MobileMessaging.resourceBundle)
		
		self.buttons = {
			let openAction = openTitle != nil ? MMNotificationAction.openAction(title: openTitle!) : MMNotificationAction.openAction()
			let dismissAction = dismissTitle != nil ? MMNotificationAction.dismissAction(title: dismissTitle!) : MMNotificationAction.dismissAction()
			let actions = [dismissAction, openAction]
			let ret = actions.map { action in
				return InteractiveMessageButton(title: action.title,
												style: action.options.contains(.destructive) ? .destructive : .default,
												isBold: action.identifier == MMNotificationAction.DefaultActionId,
                                                handler: { self.dismissAndNotifyDelegate(action) })
			}
			return ret
		}()
		
		self.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
		self.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
	}
	
	init(titleText: String?,
         messageText: String,
         imageURL: URL?,
         image: Image?,
         category: MMNotificationCategory) {
		self.titleText = titleText
		self.messageText = messageText
		self.imageURL = imageURL
		self.image = image
        self.categoryId = category.identifier
		
        super.init(nibName: "NativeInteractiveMessageAlertController", bundle: MobileMessaging.resourceBundle)
		
		self.buttons = category.actions.map { action in
            InteractiveMessageButton(
                title: action.title,
                style: action.options.contains(.destructive) ? .destructive : .default,
                isBold: action.identifier == "mm_accept",
                handler: { self.dismissAndNotifyDelegate(action) })
        }
		
		self.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
		self.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		containerView.layer.cornerRadius = 12
		containerView.layer.masksToBounds = true
		setupImageView()
		setupTitle()
		alertText.text = messageText
		setShadowAlertView()
		addButtons(actions: buttons)
		
		if NativeInteractiveMessageAlertController.tapOutsideToDismissEnabled {
			alertMaskBackground.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(NativeInteractiveMessageAlertController.dismissAction(_:))))
		}
	}
	
	//MARK: Private
	private func addButtons(actions: [InteractiveMessageButton]){
		buttons.forEach { button in
			alertActionStackView.addArrangedSubview(button)
			
			if alertActionStackView.arrangedSubviews.count > 2 {
				alertStackViewHeightConstraint.constant = NativeInteractiveMessageAlertController.buttonHeight * CGFloat(alertActionStackView.arrangedSubviews.count)
				alertActionStackView.axis = .vertical
			} else {
				alertStackViewHeightConstraint.constant = NativeInteractiveMessageAlertController.buttonHeight
				alertActionStackView.axis = .horizontal
			}
		}
	}
	
	private func dismissAndNotifyDelegate(_ action: MMNotificationAction) {
        dismiss(animated: true) {
            self.delegate?.nativeInteractiveMessageAlertControllerDidDismissWithAction(action, categoryId: self.categoryId)
        }
	}

	@objc private func dismissAction(_ sender: InteractiveMessageButton){
        dismissAndNotifyDelegate(MMNotificationAction.dismissAction())
    }
	
	private func setShadowAlertView(){
		shadowView.layer.cornerRadius = 12
		shadowView.layer.shadowOffset = CGSize.zero
		shadowView.layer.shadowRadius = 8
		shadowView.layer.shadowOpacity = 0.4
	}
	
	private func setupImageView() {
		guard imageURL != nil || image != nil else {
			headerViewHeightConstraint.constant = 0
			return
		}

		if let imageURL = imageURL {
			imageView.loadImage(withURL: imageURL, width: NativeInteractiveMessageAlertController.alertWidth, height: NativeInteractiveMessageAlertController.maxImageHeight, completion: { _, _ in
				if let height = self.imageView.imageSize(width: NativeInteractiveMessageAlertController.alertWidth, height: NativeInteractiveMessageAlertController.maxImageHeight)?.height {
					self.headerViewHeightConstraint.constant = height
				}
			})
		} else if let img = image {
			self.headerViewHeightConstraint.constant = imageHeight(image: img)
			imageView.contentImageView.contentMode = .scaleAspectFill
			imageView.contentImageView.clipsToBounds = true
			imageView.contentImageView.image = img
		}
	}
	
	private func imageHeight(image: UIImage) -> CGFloat {
		let scaleFactor = image.size.width < imageView.bounds.width ? 1 : imageView.bounds.width/image.size.width
		let imageHeight = ceil(image.size.height * scaleFactor)
		return imageHeight > NativeInteractiveMessageAlertController.maxImageHeight ? NativeInteractiveMessageAlertController.maxImageHeight : imageHeight
	}
	
	private func setupTitle() {
		alertTitle.text = titleText
		if titleText == nil {
			titleAndMessageSpace.constant = 0
		}
	}
}
