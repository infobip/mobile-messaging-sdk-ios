import UIKit

class InteractiveMessageAlertController: UIViewController {
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
	private var buttons: [InteractiveMessageButton]!
	
	var actionHandler: ((NotificationAction) -> Void)?
	var dismissHandler: (() -> Void)?
	
	init(titleText: String?, messageText: String, imageURL: URL?, category: NotificationCategory, actionHandler: ((NotificationAction) -> Void)? = nil) {
		self.titleText = titleText
		self.messageText = messageText
		self.imageURL = imageURL
		self.actionHandler = actionHandler
		
		super.init(nibName: "AlertController", bundle: Bundle(for: type(of: self)))
		
		self.buttons = {
			var ret = category.actions.map { action in
				return InteractiveMessageButton(title: action.title, style: action.options.contains(.destructive) ? .destructive : .default, handler: {
					self.actionHandler?(action)
				})
			}
			return ret
		}()
		
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
		
		if InteractiveMessageAlertController.tapOutsideToDismissEnabled {
			alertMaskBackground.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(InteractiveMessageAlertController.dismissAction(_:))))
		}
	}
	
	//MARK: Private
	private func addButtons(actions: [InteractiveMessageButton]){
		buttons.forEach { button in
			alertActionStackView.addArrangedSubview(button)
			
			if alertActionStackView.arrangedSubviews.count > 2 {
				alertStackViewHeightConstraint.constant = InteractiveMessageAlertController.buttonHeight * CGFloat(alertActionStackView.arrangedSubviews.count)
				alertActionStackView.axis = .vertical
			} else {
				alertStackViewHeightConstraint.constant = InteractiveMessageAlertController.buttonHeight
				alertActionStackView.axis = .horizontal
			}
			
			button.addTarget(self, action: #selector(InteractiveMessageAlertController.dismiss(_:)), for: .touchUpInside)
		}
	}
	
	@objc private func dismiss(_ sender: InteractiveMessageButton){
		dismiss(animated: true, completion: {
			self.dismissHandler?()
		})
	}

	@objc private func dismissAction(_ sender: InteractiveMessageButton){
		actionHandler?(NotificationAction.dismissAction)
		dismiss(animated: true, completion: {
			self.dismissHandler?()
		})
	}
	
	private func setShadowAlertView(){
		shadowView.layer.cornerRadius = 12
		shadowView.layer.shadowOffset = CGSize.zero
		shadowView.layer.shadowRadius = 8
		shadowView.layer.shadowOpacity = 0.4
	}
	
	private func setupImageView() {
		guard let imageURL = imageURL else {
			headerViewHeightConstraint.constant = 0
			return
		}
		imageView.loadImage(withURL: imageURL, width: InteractiveMessageAlertController.alertWidth, height: InteractiveMessageAlertController.maxImageHeight, completion: { _, _ in
			if let height = self.imageView.imageSize(width: InteractiveMessageAlertController.alertWidth, height: InteractiveMessageAlertController.maxImageHeight)?.height {
				self.headerViewHeightConstraint.constant = height
			}
		})
	}
	
	private func setupTitle() {
		alertTitle.text = titleText
		if titleText == nil {
			titleAndMessageSpace.constant = 0
		}
	}
}
