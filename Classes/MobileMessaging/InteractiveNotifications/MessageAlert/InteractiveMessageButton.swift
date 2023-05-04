import UIKit

enum AlertActionStyle : Int {
	case `default`
	case destructive
}

class InteractiveMessageButton: UIButton {
	private static let fontSize : CGFloat = 17.0
	private static let separatorColor = UIColor.lightGray.lighter(30)
	private let actionStyle : AlertActionStyle
	private let handler: (() -> Void)?
	private let horizontalSeparator = UIView()
	private let verticalSeparator = UIView()
	private let isBold : Bool
	
	init(title: String?, style: AlertActionStyle, isBold: Bool = false, handler: (() -> Void)?){
		self.actionStyle = style
		self.handler = handler
		self.isBold = isBold
		super.init(frame: CGRect.zero)
		self.addTarget(self, action: #selector(InteractiveMessageButton.clicked(_:)), for: .touchUpInside)
		self.setTitle(title, for: .normal)
	
		self.titleLabel?.font = isBold ? UIFont.boldSystemFont(ofSize: InteractiveMessageButton.fontSize) : UIFont.systemFont(ofSize: InteractiveMessageButton.fontSize)
		self.setTitleColor(actionStyle == .destructive ? UIColor.red : MMInteractiveMessageAlertSettings.tintColor, for: .normal)
		self.addHorizontalSeparator()
		self.addVerticalSeparator()
	}
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func clicked(_ sender: InteractiveMessageButton) {
		handler?()
	}
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		backgroundColor = UIColor.lightGray.lighter(30)
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)
		backgroundColor = UIColor.white
	}
	
	private func addHorizontalSeparator(){
		horizontalSeparator.backgroundColor = InteractiveMessageButton.separatorColor
		addSubview(horizontalSeparator)
		
		horizontalSeparator.translatesAutoresizingMaskIntoConstraints = false
		horizontalSeparator.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
		horizontalSeparator.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
		horizontalSeparator.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
		horizontalSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true
	}
	
	private func addVerticalSeparator(){
		verticalSeparator.backgroundColor = InteractiveMessageButton.separatorColor
		addSubview(verticalSeparator)
		
		verticalSeparator.translatesAutoresizingMaskIntoConstraints = false
		verticalSeparator.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
		verticalSeparator.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
		verticalSeparator.leadingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
		verticalSeparator.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 1).isActive = true
		verticalSeparator.widthAnchor.constraint(equalToConstant: 1).isActive = true
	}
}
