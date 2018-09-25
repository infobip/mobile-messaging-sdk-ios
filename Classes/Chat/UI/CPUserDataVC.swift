//
//  CPUserDataVC.swift
//  Chatpay
//
//  Created by Andrey K. on 23.07.15.
//

enum RefetchEvent {
	case onViewAppear
	case onRefreshControl
	case other
	case onNotification
}

protocol CPUserDataProtocol {
	func refetchAndReload(_ event: RefetchEvent)
	func zeroDataText() -> String
}

import UIKit

open class CPUserDataVC: CPTableViewController {
	var rc = UIRefreshControl()
	var zeroDataView: UIView!
	var isFetching: Bool = false
	var isFirstAppear: Bool = true
	var isRefreshControlEnabled: Bool = false
	
	override open func viewDidLoad() {
		super.viewDidLoad()
		setupZeroData()
		if isRefreshControlEnabled {
			rc.addTarget(self, action: #selector(CPUserDataVC.refetchAndReloadByRefresher), for: UIControl.Event.valueChanged)
			tableView.addSubview(rc)
		}
	}
	
    @objc func refetchAndReloadByRefresher() {
		self.refetchAndReload(.onRefreshControl)
	}
	
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refetchAndReload(.onViewAppear)
		isFirstAppear = false
	}
	
	func showZeroData() {
		zeroDataView.backgroundColor = view.backgroundColor
		view.bringSubviewToFront(zeroDataView)
		zeroDataView.isHidden = false
	}
	
	func hideZeroData() {
		zeroDataView.isHidden = true
	}
	
	func refetchAndReload(_ event: RefetchEvent) {
		
	}

	func zeroDataText() -> String {
		return "No data"
	}
	
	func setupZeroData() {
		zeroDataView = UIView(frame: view.bounds)
		zeroDataView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		let label = UILabel(frame: zeroDataView.bounds.inset(by: UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)))
		label.numberOfLines = 0
		label.font = UIFont.systemFont(ofSize: 17)
		label.textColor = UIColor.gray
		label.textAlignment = NSTextAlignment.center
		label.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		label.text = self.zeroDataText()
		zeroDataView.addSubview(label)
		zeroDataView.isHidden = true
		view.addSubview(zeroDataView)
	}
}
