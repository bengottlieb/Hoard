//
//  HoardCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class HoardCache: NSObject {
	public static var sharedCaches: [NSObject: HoardCache] = [:]
	
	public class func cacheForURL(URL: NSURL, type: HoardDiskCache.StorageFormat = .PNG) -> HoardCache {
		if let cache = self.sharedCaches[URL] { return cache }
		
		let cache = HoardCache(diskCacheURL: URL, type: type)
		self.sharedCaches[URL] = cache
		return cache
	}
	
	public class func cacheForKey(key: String, type: HoardDiskCache.StorageFormat = .PNG) -> HoardCache {
		if let cache = self.sharedCaches[key] { return cache }
		
		let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
		let URL = urls[0].URLByAppendingPathComponent(key)
		let cache = HoardCache(diskCacheURL: URL, type: type)
		self.sharedCaches[key] = cache
		return cache
	}
	
	init(diskCacheURL: NSURL? = nil, type: HoardDiskCache.StorageFormat = .Data) {
		if let url = diskCacheURL {
			diskCache = HoardDiskCache(URL: url, type: type)
		} else {
			diskCache = nil
		}
	}
	
	public let diskCache: HoardDiskCache?
	public let cache = NSCache()
	
	public func flushCache() {
		self.cache.removeAllObjects()
	}
	
	public func nukeCache() {
		self.cache.removeAllObjects()
		self.diskCache?.nukeCache()
	}
	
	public func store(target: NSObject?, from URL: NSURL) -> Bool {
		var cost = 0
		if let object = target {
			if let cached = object as? HoardCacheStoredObject { cost = cached.hoardCacheCost }
			self.cache.setObject(object, forKey: URL.cacheKey, cost: cost)
			
			if let cache = self.diskCache, cachable = object as? HoardDiskCachable {
				return cache.storeData(cachable.hoardCacheData, from: URL)
			}
			
			return true
		} else {
			self.remove(URL)
			return false
		}
	}

	public func remove(URL: NSURL) {
		self.cache.removeObjectForKey(URL.cacheKey)
		self.diskCache?.remove(URL)
	}
	
	public func fetch(from: NSURL) -> NSObject? {
		if let object = self.cache.objectForKey(from.cacheKey) { return object as? NSObject }
		return self.diskCache?.fetchData(from)
	}
	
	public func isCacheDataAvailable(URL: NSURL) -> Bool {
		if self.cache.objectForKey(URL.cacheKey) != nil { return true }
		return self.diskCache?.isCacheDataAvailable(URL) ?? false
	}
}
