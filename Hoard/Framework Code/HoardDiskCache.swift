//
//  HoardDiskCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class HoardDiskCache {
	public enum ImageStorage: Int { case JPEG, PNG }
	
	public var imageStorageType = ImageStorage.JPEG
	public let baseURL: NSURL
	public let valid: Bool
	public var imageStorageQuality: CGFloat = 0.9
	
	public static var sharedCaches: [NSURL: HoardDiskCache] = [:]
	
	public class func cacheForURL(URL: NSURL, type: ImageStorage = .JPEG) -> HoardDiskCache {
		if let cache = self.sharedCaches[URL] { return cache }
		
		let cache = HoardDiskCache(URL: URL, type: type)
		self.sharedCaches[URL] = cache
		return cache
	}
	
	public class func cacheForKey(key: String, type: ImageStorage = .JPEG) -> HoardDiskCache {
		let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
		let URL = urls[0].URLByAppendingPathComponent(key)
		return self.cacheForURL(URL, type: type)
	}
	
	public init(URL: NSURL, type: ImageStorage = .JPEG) {
		baseURL = URL
		imageStorageType = type
		do {
			try NSFileManager.defaultManager().createDirectoryAtURL(URL, withIntermediateDirectories: true, attributes: nil)
			valid = true
		} catch let error {
			print("Unable to instantiate a disk cache at \(URL.path!): \(error)")
			valid = false
		}
	}
	
	public func clearCache() {
		do {
			try NSFileManager.defaultManager().removeItemAtURL(self.baseURL)
			try NSFileManager.defaultManager().createDirectoryAtURL(self.baseURL, withIntermediateDirectories: true, attributes: nil)
		} catch let error as NSError {
			print("Error while clearing Hoard cache: \(error)")
		}
	}
	
	public func store(data: NSData?, from URL: NSURL) -> Bool {
		if !self.valid { return false }
		
		if let data = data {
			let cacheURL = self.localURLForURL(URL)
			return data.writeToURL(cacheURL, atomically: true)
		} else {
			self.remove(URL)
		}
		
		return true
	}
	
	public func remove(URL: NSURL) {
		let cacheURL = self.localURLForURL(URL)
		
		do {
			try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
		} catch let error {
			print("Failed to remove cached data for URL \(URL.path!): \(error)")
		}
	}
	
	public func fetch(from: NSURL) -> NSData? {
		let data = NSData(contentsOfURL:  self.localURLForURL(from))
		return data
	}
	
	
	public func isCacheDataAvailable(URL: NSURL) -> Bool {
		return NSFileManager.defaultManager().fileExistsAtPath(self.localURLForURL(URL).path ?? "/null")
	}
	
	public func localURLForURL(URL: NSURL) -> NSURL {
		return self.baseURL.URLByAppendingPathComponent(URL.cachedFilename)
	}
}

extension NSURL {
	public var cachedFilename: String {
		let basic = self.lastPathComponent ?? "--"
		let ext = self.pathExtension ?? "dat"
		return "\(self.hash)-" + basic + "." + ext
	}
}