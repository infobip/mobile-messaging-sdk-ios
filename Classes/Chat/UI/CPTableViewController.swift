//
//  CPTableViewController.swift
//
//  Created by Andrey Kadochnikov on 12.08.15.
//

import UIKit

open class CPTableViewController: CPViewController {

	var tableViewStyle = UITableView.Style.plain
    var tableView: UITableView!
    
	override open func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: view.bounds, style: tableViewStyle)
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
    }
    
    // MARK: - Keyboard
	override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        super.keyboardWillHide(duration, curve: curve, options: options, height: height)
        let block = {
            self.tableView.frame.y = 0
            self.tableView.contentInset.top = 0
            self.tableView.scrollIndicatorInsets = self.tableView.contentInset
        }
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
    }
    
	override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
				
        super.keyboardWillShow(duration, curve: curve, options: options, height: height)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: { () -> Void in
            self.tableView.contentInset.top = height
            self.tableView.frame.y = -height
            self.tableView.scrollIndicatorInsets = self.tableView.contentInset
        }, completion: nil)
    }
}

extension CPTableViewController : UITableViewDataSource, UITableViewDelegate {
	public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
	public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell! = nil
        return cell
    }
}
