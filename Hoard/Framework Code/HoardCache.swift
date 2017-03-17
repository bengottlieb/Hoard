//
//  Cache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CrossPlatformKit

open class Cache: NSObject {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	open static var sharedCaches: [NSObject: Cache] = [:]
	
	open class func sensibleMemorySizeForCurrentDevice() -> Int64 {
		let info = ProcessInfo()
		let total = Double(info.physicalMemory / (1024 * 1024))
		let maxRatio = total <= (512) ? 0.1 : 0.2
		let max = min(Int64(total * maxRatio), 50) * 1024 * 1024
		return max
	}
	
	open override var description: String {
		let formatter = ByteCountFormatter()
		let sizeString = formatter.string(fromByteCount: self.currentSize)
		let maxString = formatter.string(fromByteCount: self.maxSize)
		let prefix = self.cacheDescription == nil ? "" : "\(self.cacheDescription!): "
		return "\(prefix)\(self.mapTable.count) objects, \(sizeString) of \(maxString)"
	}
	
	open class func cacheForURL(_ URL: Foundation.URL, type: DiskCache.StorageFormat = .png, description: String? = nil) -> Cache {
		if let existing = self.sharedCaches[URL as NSURL] { return existing }
		
		let cache = Cache(diskCacheURL: URL, type: type, description: description)
		self.sharedCaches[URL as NSURL] = cache
		return cache
	}
	
	open class func cacheForKey(_ key: String, type: DiskCache.StorageFormat = .png, description: String? = nil) -> Cache {
		let objectKey = key as NSString
		if let cache = self.sharedCaches[objectKey] { return cache }
		
		let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
		let URL = urls[0].appendingPathComponent(key)
		let cache = Cache(diskCacheURL: URL, type: type, description: description)
		self.sharedCaches[objectKey] = cache
		return cache
	}
	
	init(diskCacheURL: URL? = nil, type: DiskCache.StorageFormat = .data, description desc: String? = nil) {
		if let url = diskCacheURL {
			diskCache = DiskCache(URL: url, type: type, description: (desc ?? "") + " Disk Cache")
		} else {
			diskCache = nil
		}
		
		cacheDescription = desc
		serialQueue = OperationQueue()
		serialQueue.maxConcurrentOperationCount = 1
		serialQueue.qualityOfService = .userInteractive
		mapTable = NSMapTable(keyOptions: NSPointerFunctions.Options(), valueOptions: NSPointerFunctions.Options())
		super.init()
		#if os(iOS)
			NotificationCenter.default.addObserver(self, selector: #selector(Cache.didReceiveMemoryWarning(_:)), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
		#endif
	}
	
	open let diskCache: DiskCache?
	open var currentSize: Int64 = 0
	open var maxSize = Cache.sensibleMemorySizeForCurrentDevice() { didSet {
			self.prune()
		}
	}
	
	let serialQueue: OperationQueue
	var mapTable: NSMapTable<AnyObject, AnyObject>
	let cacheDescription: String?
	
	func serialize(_ block: @escaping () -> Void) { self.serialQueue.addOperation(block) }
	
	open func flushCache() {
		self.serialize {
			self.mapTable = NSMapTable(keyOptions: NSPointerFunctions.Options(), valueOptions: NSPointerFunctions.Options())
			self.currentSize = 0
		}
	}
	
	public func nuke() {
		self.flushCache()
		self.diskCache?.clearOut()
	}
	
	open func store(_ target: NSObject?, from URL: Foundation.URL, skipDisk: Bool = false) {
		self.serialize {
			var size = 0
			if let object = target {
				let key = URL.cacheKey as NSString
				if let existing = self.mapTable.object(forKey: key) as? CachedObjectInfo {
					if existing.object == object { return }
					
					self.currentSize -= existing.size
					self.mapTable.removeObject(forKey: key)
				}

				if let cached = object as? CacheStoredObject {
					size = cached.hoardCacheSize
				} else if let image = object as? UXImage {
					size = image.hoardCacheSize
				} else {
					print("not a cachable object")
				}
				self.currentSize += size
				self.mapTable.setObject(CachedObjectInfo(object: object, size: size, key: key), forKey: key)
				
				if !skipDisk, let cache = self.diskCache, let cachable = object as? HoardDiskCachable {
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

	open func remove(_ URL: Foundation.URL) {
		self.serialize {
			let key = URL.cacheKey as NSString
			if let current = self.mapTable.object(forKey: key) as? CachedObjectInfo {
				self.currentSize -= current.size
				self.mapTable.removeObject(forKey: key)
				self.diskCache?.remove(URL)
			}
		}
	}
	
	open func fetch(_ from: URL) -> NSObject? {
		if let info = self.mapTable.object(forKey: from.cacheKey) as? CachedObjectInfo {
			self.diskCache?.updateAccessedAtForRemoteURL(from)
			info.accessedAt = Date().timeIntervalSinceReferenceDate
			return info.object
		}
		return nil //self.diskCache?.fetchData(from)
	}
	
	open func isCacheDataAvailable(_ URL: Foundation.URL) -> Bool {
		if self.mapTable.object(forKey: URL.cacheKey) != nil { return true }
		return self.diskCache?.isCacheDataAvailable(URL) ?? false
	}
	
	open func prune(_ size: Int64? = nil) {
		HoardState.addMaintenanceBlock {
			self.serialize {
				let limit = size ?? self.maxSize
				if self.currentSize < limit { return }
			
				let current = self.objectsSortedByLastAccess
				var index = 0
			
				while self.currentSize >= limit && index < current.count && current.count > 1 {
					let oldest = current[index]
					self.currentSize -= oldest.size
					self.mapTable.removeObject(forKey: oldest.key as AnyObject?)
				}
				index += 1
			}
		}
	}
	
	func didReceiveMemoryWarning(_ note: Notification) {
		self.flushCache()
	}
}


extension Cache {
	var objectsSortedByLastAccess: [Cache.CachedObjectInfo] {
		if let objects = self.mapTable.objectEnumerator()?.allObjects as? [Cache.CachedObjectInfo] {
			return objects.sorted { return $0.accessedAt < $1.accessedAt }
		}
		return []
	}
}

extension Cache {
	class CachedObjectInfo {
		let object: NSObject
		let size: Int
		var accessedAt: TimeInterval
		let key: NSString
		
		init(object obj: NSObject, size sz: Int, key cacheKey: NSString, date: Date? = nil) {
			object = obj
			size = sz
			accessedAt = (date ?? Date()).timeIntervalSinceReferenceDate
			key = cacheKey
		}
	}
}
