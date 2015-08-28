//
//  HoardDiskCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class HoardDiskCache {
	public enum ImageStorage: Int { case None, JPEG, PNG
		var suggestedFileExtension: String? {
		switch self {
		case .None: return nil
		case .JPEG: return "jpg"
		case .PNG: return "png"
		}}
	}
	
	public var imageStorageType = ImageStorage.JPEG
	public let baseURL: NSURL
	public let valid: Bool
	public var imageStorageQuality: CGFloat = 0.9
	
	public static var sharedCaches: [NSObject: HoardDiskCache] = [:]
	
	public class func cacheForURL(URL: NSURL, type: ImageStorage = .JPEG) -> HoardDiskCache {
		if let cache = self.sharedCaches[URL] { return cache }
		
		let cache = HoardDiskCache(URL: URL, type: type)
		self.sharedCaches[URL] = cache
		return cache
	}
	
	public class func cacheForKey(key: String, type: ImageStorage = .JPEG) -> HoardDiskCache {
		if let cache = self.sharedCaches[key] { return cache }

		let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
		let URL = urls[0].URLByAppendingPathComponent(key)
		let cache = HoardDiskCache(URL: URL, type: type)
		self.sharedCaches[key] = cache
		return cache
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
	
	public func store(data: NSData?, from URL: NSURL, suggestedFileExtension: String? = nil) -> Bool {
		if !self.valid { return false }
	
		let ext = suggestedFileExtension ?? self.imageStorageType.suggestedFileExtension

		if let data = data {
			let cacheURL = self.localURLForURL(URL, suggestedFileExtension: ext)
			return data.writeToURL(cacheURL, atomically: true)
		} else {
			self.remove(URL)
		}
		
		return true
	}
	
	public func remove(URL: NSURL, suggestedFileExtension: String? = nil) {
		let ext = suggestedFileExtension ?? self.imageStorageType.suggestedFileExtension
		let cacheURL = self.localURLForURL(URL, suggestedFileExtension: ext)
		
		do {
			try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
		} catch let error {
			print("Failed to remove cached data for URL \(URL.path!): \(error)")
		}
	}
	
	public func fetch(from: NSURL, suggestedFileExtension: String? = nil) -> NSData? {
		let ext = suggestedFileExtension ?? self.imageStorageType.suggestedFileExtension
		let data = NSData(contentsOfURL:  self.localURLForURL(from, suggestedFileExtension: ext))
		return data
	}
	
	
	public func isCacheDataAvailable(URL: NSURL, suggestedFileExtension: String? = nil) -> Bool {
		let ext = suggestedFileExtension ?? self.imageStorageType.suggestedFileExtension
		return NSFileManager.defaultManager().fileExistsAtPath(self.localURLForURL(URL, suggestedFileExtension: ext).path ?? "/null")
	}
	
	public func localURLForURL(URL: NSURL, suggestedFileExtension: String? = nil) -> NSURL {
		return self.baseURL.URLByAppendingPathComponent(URL.cachedFilename(suggestedFileExtension))
	}
}

extension NSURL {
	public func cachedFilename(suggestedFileExtension: String? = nil) -> String {
		let basic = self.lastPathComponent ?? "--"
		let currentExt = self.pathExtension ?? ""
		let ext = currentExt.isEmpty ? (suggestedFileExtension ?? "dat") : currentExt
		return "\(self.hash)-" + basic + "." + ext
	}
}