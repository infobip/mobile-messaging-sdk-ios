//
//  CPTableViewCell.swift
//  Chatpay
//
//  Created by Andrey K. on 15.07.15.
//

import UIKit

class CPTableViewCell: UITableViewCell {
    var textInsets: UIEdgeInsets = UIEdgeInsets.zero
	var originalAccessoryType = UITableViewCell.AccessoryType.none
    
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        switch style {
        case .value1:
            self.textLabel?.font = UIFont.systemFont(ofSize: 16)
        default:
            self.textLabel?.font = UIFont.systemFont(ofSize: 16)
        }
        
        self.textLabel?.textColor = UIColor.black
        self.detailTextLabel?.textColor = UIColor.gray
        self.layoutMargins = UIEdgeInsets.zero
        self.preservesSuperviewLayoutMargins = false
		self.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		self.selectionStyle = UITableViewCell.SelectionStyle.default
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
		textLabel!.frame = textLabel!.frame.inset(by: textInsets)
    }
    
    var enabled: Bool = true {
        didSet {
			if self.accessoryType != UITableViewCell.AccessoryType.none {
                originalAccessoryType = self.accessoryType
            }
            self.isUserInteractionEnabled = self.enabled
            self.accessoryType = self.enabled ? self.originalAccessoryType : .none
            self.refreshColors()
        }
    }
    
    func refreshColors() {
        var color: UIColor!
        if (self.enabled){
            color = UIColor.enabledCellColor()
        } else {
            color = UIColor.disabledCellColor()
        }
        self.contentView.subviews.forEach({ (view: UIView) -> Void in
            view.alpha = self.enabled ? 1 : 0.6
        })
        self.backgroundColor = color
        self.accessoryView?.backgroundColor = UIColor.clear
        self.contentView.backgroundColor = UIColor.clear
    }
    
    var selectedColor: UIColor? {
        set {
			let selectedView = UIView()
			selectedView.backgroundColor = newValue
			self.selectedBackgroundView = selectedView
        }
        get {
            return self.selectedBackgroundView?.backgroundColor ?? UIColor.clear
        }
    }

}
