//
//  utils.swift
//  InboxExample
//
//  Created by Andrey Kadochnikov on 26.05.2022.
//

import Foundation
import UIKit

enum NotificationKeys {
     static let unreadCount: String = "unreadCount"
}

extension Notification.Name {
    // Notifications
    static let inboxCountersUpdated = Notification.Name("inboxCountersUpdated")
}

func showAlertInRootVC(_ error: NSError) {
    UIApplication.shared.keyWindow!.rootViewController?.showAlertIfErrorPresent(error)
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
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: dismissActionHandler))
            self.present(alert, animated: true, completion: nil)
        }
    }
    func showAlertIfErrorPresent(_ error: Error?) {
        guard let error = error else {
            return
        }
        self.showAlert("Error", message: error.localizedDescription)
    }
}
