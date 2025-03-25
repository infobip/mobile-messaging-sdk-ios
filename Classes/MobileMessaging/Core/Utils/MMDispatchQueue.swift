//
//  MMDispatchQueue.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 22/03/2024.
//

import Foundation

extension DispatchQueue {
    // This method makes sure the completion is triggered in main thread. If it is already, it will be called synchronously.
    // Otherwise, the completion will be called in main asynchronously
    public static func mmEnsureMain(completion: @escaping @convention(block) () -> Void) {
        if Thread.isMainThread {
            completion()
        } else {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
