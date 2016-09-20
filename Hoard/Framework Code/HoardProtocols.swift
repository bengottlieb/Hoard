//
//  HoardProtocols.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

extension URL {
	public var cacheKey: NSString {
		let filename = self.lastPathComponent
		return (filename + "-" + self.absoluteString) as NSString
	}
}

extension Data: CacheStoredObject, HoardDiskCachable {
	var hoardCacheData: Data { return self }
	var hoardCacheSize: Int { return self.count }
}

protocol CacheStoredObject {
	var hoardCacheSize: Int { get }
}


protocol HoardDiskCachable {
	var hoardCacheData: Data { get }
}
