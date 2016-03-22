//
//  Cache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

extension Hoard {
	public class Cache: NSObject {
		deinit {
			NSNotificationCenter.defaultCenter().removeObserver(self)
		}
		public static var sharedCaches: [NSObject: Cache] = [:]
		
		public class func sensibleMemorySizeForCurrentDevice() -> Int64 {
			let info = NSProcessInfo()
			let total = Double(info.physicalMemory / (1024 * 1024))
			let maxRatio = total <= (512) ? 0.1 : 0.2
			let max = min(Int64(total * maxRatio), 50) * 1024 * 1024
			return max
		}
		
		public override var description: String {
			let formatter = NSByteCountFormatter()
			let sizeString = formatter.stringFromByteCount(self.currentSize)
			let maxString = formatter.stringFromByteCount(self.maxSize)
			let prefix = self.cacheDescription == nil ? "" : "\(self.cacheDescription!): "
			return "\(prefix)\(self.mapTable.count) objects, \(sizeString) of \(maxString)"
		}
		
		public class func cacheForURL(URL: NSURL, type: DiskCache.StorageFormat = .PNG, description: String? = nil) -> Cache {
			if let existing = self.sharedCaches[URL] { return existing }
			
			let cache = Cache(diskCacheURL: URL, type: type, description: description)
			self.sharedCaches[URL] = cache
			return cache
		}
		
		public class func cacheForKey(key: String, type: DiskCache.StorageFormat = .PNG, description: String? = nil) -> Cache {
			if let cache = self.sharedCaches[key] { return cache }
			
			let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
			let URL = urls[0].URLByAppendingPathComponent(key)
			let cache = Cache(diskCacheURL: URL, type: type, description: description)
			self.sharedCaches[key] = cache
			return cache
		}
		
		init(diskCacheURL: NSURL? = nil, type: DiskCache.StorageFormat = .Data, description desc: String? = nil) {
			if let url = diskCacheURL {
				diskCache = DiskCache(URL: url, type: type, description: (desc ?? "") + " Disk Cache")
			} else {
				diskCache = nil
			}
			
			cacheDescription = desc
			serialQueue = NSOperationQueue()
			serialQueue.maxConcurrentOperationCount = 1
			serialQueue.qualityOfService = .UserInteractive
			mapTable = NSMapTable(keyOptions: [.StrongMemory, .ObjectPersonality], valueOptions: [.StrongMemory, .ObjectPersonality])
			super.init()
			NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Cache.didReceiveMemoryWarning(_:)), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
		}
		
		public let diskCache: DiskCache?
		public var currentSize: Int64 = 0
		public var maxSize = Cache.sensibleMemorySizeForCurrentDevice() { didSet {
				self.prune()
			}
		}
		
		let serialQueue: NSOperationQueue
		var mapTable: NSMapTable
		let cacheDescription: String?
		
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
						self.mapTable.removeObjectForKey(key)
					}

					if let cached = object as? CacheStoredObject {
						size = cached.hoardCacheSize
					} else if let image = object as? UIImage {
						size = image.hoardCacheSize
					} else {
						print("not a cachable object")
					}
					self.currentSize += size
					self.mapTable.setObject(CachedObjectInfo(object: object, size: size, key: key), forKey: key)
					
					if !skipDisk, let cache = self.diskCache, cachable = object as? HoardDiskCachable {
						cache.storeData(cachable.hoardCacheData, from: URL)
						return
					}
					
					self.prune()
					self.diskCache?.store(object, from: URL)
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
				self.serialize {
					let limit = size ?? self.maxSize
					if self.currentSize < limit { return }
				
					let current = self.objectsSortedByLastAccess
					var index = 0
				
					while self.currentSize >= limit && index < current.count && current.count > 1 {
						let oldest = current[index]
						self.currentSize -= oldest.size
						self.mapTable.removeObjectForKey(oldest.key)
					}
					index += 1
				}
			}
		}
		
		func didReceiveMemoryWarning(note: NSNotification) {
			self.flushCache()
		}
	}
}


extension Hoard.Cache {
	var objectsSortedByLastAccess: [Hoard.Cache.CachedObjectInfo] {
		if let objects = self.mapTable.objectEnumerator()?.allObjects as? [Hoard.Cache.CachedObjectInfo] {
			return objects.sort { return $0.accessedAt < $1.accessedAt }
		}
		return []
	}
}

extension Hoard.Cache {
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
}