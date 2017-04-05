//
//  HoardProtocols.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CrossPlatformKit

extension URL {
	public var cacheKey: NSString {
		let filename = self.lastPathComponent
		return (filename + "-" + self.absoluteString) as NSString
	}
}

extension Data: CacheStoredObject, HoardDiskCachable {
	public var hoardCacheData: Data { return self }
	public var hoardCacheSize: Int { return self.count }
}

public protocol CacheStoredObject {
	var hoardCacheSize: Int { get }
}


public protocol HoardDiskCachable {
	var hoardCacheData: Data { get }
	var hashValue: Int { get }
}

func ==(lhs: HoardDiskCachable, rhs: HoardDiskCachable) -> Bool {
	return lhs.hashValue == rhs.hashValue
}


extension UXImage: HoardDiskCachable {
	public var hoardCacheData: Data { return self.pngData() ?? Data() }
	public var hoardCacheSize: Int { return Int(self.size.width) * Int(self.size.height) }
}
