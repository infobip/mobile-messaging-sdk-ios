// 
//  MMOpenSettings.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
            guard let viewController = UIApplication.shared.mmkeyWindow?.rootViewController else {
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
                foregroundColor: MMWebRTCSettings.sharedInstance.foregroundColor,
                backgroundColor: MMWebRTCSettings.sharedInstance.backgroundColor,
                actions: [gotoSettingsAction, cancelAction],
                in: viewController)
        }
    }
}
#endif
