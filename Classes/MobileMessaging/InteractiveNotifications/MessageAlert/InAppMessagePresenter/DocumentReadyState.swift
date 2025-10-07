// 
//  DocumentReadyState.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// Possible values of browser's `document.readyState`.
enum DocumentReadyState: String {
    /// The document is loading.
    case loading
    /// The document was fully read.
    case interactive
    /// The document and all resources were loaded.
    case complete
}
