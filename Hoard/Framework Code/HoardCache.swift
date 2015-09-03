//
//  HoardCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class HoardCache: NSObject {
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	public static var sharedCaches: [NSObject: HoardCache] = [:]
	
	public class func sensibleMemorySizeForCurrentDevice() -> Int64 {
		let info = NSProcessInfo()
		let total = Double(info.physicalMemory / (1024 * 1024))
		let maxRatio = total <= (512) ? 0.1 : 0.2
		let max = min(Int64(total * maxRatio), 50) * 1024 * 1024
		return max
	}
	
	public class func cacheForURL(URL: NSURL, type: HoardDiskCache.StorageFormat = .PNG) -> HoardCache {
		if let existing = self.sharedCaches[URL] { return existing }
		
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
		
		serialQueue = NSOperationQueue()
		serialQueue.maxConcurrentOperationCount = 1
		serialQueue.qualityOfService = .UserInteractive
		mapTable = NSMapTable(keyOptions: [.StrongMemory, .ObjectPersonality], valueOptions: [.StrongMemory, .ObjectPersonality])
		super.init()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveMemoryWarning:", name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
	}
	
	public let diskCache: HoardDiskCache?
	public var currentSize: Int64 = 0
	public var maxSize = HoardCache.sensibleMemorySizeForCurrentDevice() { didSet {
			self.prune()
		}
	}
	
	let serialQueue: NSOperationQueue
	var mapTable: NSMapTable
	
	func serialize(block: () -> Void) { self.serialQueue.addOperationWithBlock(block) }
	
	public func flushCache() {
		self.serialize {
			self.mapTable = NSMapTable(keyOptions: [.StrongMemory, .ObjectPersonality], valueOptions: [.StrongMemory, .ObjectPersonality])
			self.currentSize = 0
		}
	}
	
	public func nukeCache() {
		self.flushCache()
		self.diskCache?.nukeCache()
	}
	
	public func store(target: NSObject?, from URL: NSURL, skipDisk: Bool = false) {
		self.serialize {
			var size = 0
			if let object = target {
				let key = URL.cacheKey
				if let existing = self.mapTable.objectForKey(key) as? CachedObjectInfo {
					if existing.object == object { return }
					
					self.currentSize -= existing.size
				}

				if let cached = object as? HoardCacheStoredObject { size = cached.hoardCacheSize }
				self.currentSize += size
				self.mapTable.setObject(CachedObjectInfo(object: object, size: size, key: key), forKey: key)
				
				if !skipDisk, let cache = self.diskCache, cachable = object as? HoardDiskCachable {
					cache.storeData(cachable.hoardCacheData, from: URL)
					return
				}
				
				self.prune()
			} else {
				self.remove(URL)
			}
		}
	}

	public func remove(URL: NSURL) {
		self.serialize {
			let key = URL.cacheKey
			if let current = self.mapTable.objectForKey(key) as? CachedObjectInfo {
				self.currentSize -= current.size
				self.mapTable.removeObjectForKey(key)
				self.diskCache?.remove(URL)
			}
		}
	}
	
	public func fetch(from: NSURL) -> NSObject? {
		if let info = self.mapTable.objectForKey(from.cacheKey) as? CachedObjectInfo {
			self.diskCache?.updateAccessedAtForRemoteURL(from)
			info.accessedAt = NSDate().timeIntervalSinceReferenceDate
			return info.object
		}
		return self.diskCache?.fetchData(from)
	}
	
	public func isCacheDataAvailable(URL: NSURL) -> Bool {
		if self.mapTable.objectForKey(URL.cacheKey) != nil { return true }
		return self.diskCache?.isCacheDataAvailable(URL) ?? false
	}
	
	public func prune(size: Int64? = nil) {
		Hoard.addMaintenanceBlock {
			let limit = size ?? self.maxSize
			if self.currentSize < limit { return }
			
			let current = self.objectsSortedByLastAccess
			var index = 0
			
			while self.currentSize >= limit && index < current.count {
				let oldest = current[index]
				self.serialize {
					self.currentSize -= oldest.size
					self.mapTable.removeObjectForKey(oldest.key)
				}
				index++
			}
		}
	}
	
	func didReceiveMemoryWarning(note: NSNotification) {
		self.flushCache()
	}
}

extension HoardCache {
	var objectsSortedByLastAccess: [CachedObjectInfo] {
		let objects = self.mapTable.objectEnumerator()?.allObjects as! [CachedObjectInfo]
		
		return objects.sort { return $0.accessedAt > $1.accessedAt }
	}
}


class CachedObjectInfo {
	let object: NSObject
	let size: Int
	var accessedAt: NSTimeInterval
	let key: String
	
	init(object obj: NSObject, size sz: Int, key cacheKey: String, date: NSDate? = nil) {
		object = obj
		size = sz
		accessedAt = (date ?? NSDate()).timeIntervalSinceReferenceDate
		key = cacheKey
	}
}