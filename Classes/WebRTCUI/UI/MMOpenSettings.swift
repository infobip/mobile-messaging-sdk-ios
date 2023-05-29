//
//  MMOpenSettings.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 12/10/2022.
//

import Foundation
import AVFoundation
import UIKit
#if WEBRTCUI_ENABLED

public protocol MMOpenSettings {
    func askForSystemSettings(
        title: String,
        description: String,
        completion: ((Bool) -> Void)?)
}

public extension MMOpenSettings {
    func askForSystemSettings(
        title: String,
        description: String,
        completion: ((Bool) -> Void)?
    ) {
        DispatchQueue.main.async {
            guard let viewController = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?
                    .rootViewController else {
                return
            }
            let gotoSettingsAction = UIAlertAction(title: MMLoc.settings, style: .default, handler: { _ in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                      UIApplication.shared.canOpenURL(settingsUrl) else {
                    completion?(false)
                    return
                }
                UIApplication.shared.open(settingsUrl, options: [:]) { _ in
                    viewController.dismiss(animated: false, completion: nil)
                }
            })
            let cancelAction = UIAlertAction(
                title: MMLoc.cancel,
                style: .cancel,
                handler: { _ in completion?(false) })
             MMPopupView.display(
                title: title,
                message: description,
                style: .info,
                actions: [gotoSettingsAction, cancelAction],
                in: viewController)
        }
    }
}
#endif
