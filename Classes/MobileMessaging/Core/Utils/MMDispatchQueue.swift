// 
//  MMDispatchQueue.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
