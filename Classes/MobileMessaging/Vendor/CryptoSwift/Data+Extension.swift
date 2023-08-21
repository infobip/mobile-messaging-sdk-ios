//
//  Data+Extension.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 16/04/2018.
//

import Foundation

extension Data {
	public init(hex: String) {
		self.init(Array<UInt8>(hex: hex))
	}
	
	public var bytes: Array<UInt8> {
		return Array(self)
	}
	
	public func toHexString() -> String {
		return bytes.toHexString()
	}
}
