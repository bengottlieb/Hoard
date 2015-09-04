//
//  HoardProtocols.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import UIKit

extension NSURL {
	public var cacheKey: String {
		let filename = self.lastPathComponent ?? ""
		return filename + "-" + self.absoluteString
	}
}

extension NSData {
	var hoardCacheData: NSData { return self }
}

@objc protocol CacheStoredObject {
	var hoardCacheSize: Int { get }
}


@objc protocol HoardDiskCachable {
	var hoardCacheData: NSData { get }
}