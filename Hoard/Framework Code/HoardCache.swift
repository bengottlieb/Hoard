//
//  Cache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/31/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CrossPlatformKit
import Plug

open class Cache: NSObject {
	public static var defaultImageCache = Cache.cache(for: Cache.mainImageCacheKey)
	public static let mainImageCacheKey = "main-hoard-cache"

	let semaphore = DispatchSemaphore(value: 1)
	public let diskCache: DiskCache?
	public weak var delegate: HoardCacheDelegate?
	public var currentSize: Int64 = 0
	public var maxSize = Cache.sensibleMemorySizeForCurrentDevice() { didSet {
		self.prune()
		}
	}
	
	var mapTable: NSMapTable<AnyObject, AnyObject>
	var prefetchCancelled = false
	let cacheDescription: String?
	
	public static var sharedCaches: [AnyHashable: Cache] = [:]
	
	open static func hasData(for url: URL) -> Bool {
		for (_, cache) in self.sharedCaches {
			if cache.hasData(for: url) { return true }
		}
		return false
	}
	
	open static func fetch<T: HoardDiskCachable> (for url: URL, moreRecentThan: Date? = nil) -> T? {
		for (_, cache) in self.sharedCaches {
			if let item: T = cache.fetch(for: url, moreRecentThan: moreRecentThan) {
				return item
			}
		}
		return nil
	}

	open static func removeData(for url: URL) {
		for (_, cache) in self.sharedCaches {
			cache.remove(url)
			cache.diskCache?.remove(url)
		}
	}
	
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
	
	open class func cache(for url: URL, type: DiskCache.StorageFormat = .png, description: String? = nil) -> Cache {
		if let existing = self.sharedCaches[url] { return existing }
		
		let cache = Cache(diskCacheURL: url, type: type, description: description)
		self.sharedCaches[url] = cache
		return cache
	}
	
	open class func cache(for key: String, type: DiskCache.StorageFormat = .png, description: String? = nil) -> Cache {
		let objectKey = key as NSString
		if let cache = self.sharedCaches[objectKey] { return cache }
		
		let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
		var url = urls[0]
		
		if let bundleID = Bundle.main.bundleIdentifier { url = url.appendingPathComponent(bundleID) }
		url = url.appendingPathComponent(key)
		
		let cache = Cache(diskCacheURL: url, type: type, description: description)
		self.sharedCaches[objectKey] = cache
		return cache
	}
	
	init(diskCacheURL: URL? = nil, type: DiskCache.StorageFormat = .data, description desc: String? = nil) {
		if let url = diskCacheURL {
			self.diskCache = DiskCache(url: url, type: type, description: (desc ?? "") + " Disk Cache")
		} else {
			self.diskCache = nil
		}
		
		self.cacheDescription = desc
		self.mapTable = NSMapTable(keyOptions: NSPointerFunctions.Options(), valueOptions: NSPointerFunctions.Options())
		super.init()
		#if os(iOS)
			NotificationCenter.default.addObserver(self, selector: #selector(Cache.didReceiveMemoryWarning), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
		#endif
	}
	
	open func flushCache() {
		self.semaphore.wait()
		defer { self.semaphore.signal() }
		self.mapTable = NSMapTable(keyOptions: NSPointerFunctions.Options(), valueOptions: NSPointerFunctions.Options())
		self.currentSize = 0
	}
	
	public func nuke() {
		self.cancelPrefetch()
		self.flushCache()
		self.diskCache?.clearOut()
	}
	
	open func cancelPrefetch() {
		self.prefetchCancelled = true
		self.diskCache?.prefetchCancelled = true
	}
	
	open func prefetch(from url: URL, validUntil: Date? = nil, completion: (() -> Void)? = nil) { self.prefetch(from: [url], validUntil: validUntil, completion: completion) }
	open func prefetch(from urls: [URL], validUntil: Date? = nil, progress: ((Int) -> Void)? = nil, completion: (() -> Void)? = nil) {
		guard let disk = self.diskCache else {
			completion?()
			return
		}
		self.prefetchCancelled = false
		disk.prefetch(from: urls, validUntil: validUntil, progress: progress, completion: completion)
	}

	open func store(object: HoardDiskCachable?, from url: URL, skipDisk: Bool = false, validUntil: Date? = nil) {
		self.semaphore.wait()
		defer { self.semaphore.signal() }
		var size = 0
		if let object = object {
			let key = url.cacheKey as NSString
			if let existing = self.mapTable.object(forKey: key) as? CachedObjectInfo {
				if existing.object == object { return }
				
				self.currentSize -= Int64(existing.size)
				self.mapTable.removeObject(forKey: key)
			}

			if let cached = object as? CacheStoredObject {
				size = cached.hoardCacheSize
			} else if let image = object as? UXImage {
				size = image.hoardCacheSize
			} else {
				print("not a cachable object")
			}
			self.currentSize += Int64(size)
			self.mapTable.setObject(CachedObjectInfo(object: object, size: size, key: key), forKey: key)
			
			if !skipDisk, let cache = self.diskCache {
				cache.storeData(object.hoardCacheData, from: url)
				return
			}
			
			self.prune()
			self.diskCache?.store(object: object, from: url, validUntil: validUntil)
		} else {
			self.remove(url)
		}
	}
	
	open func hasData(for url: URL) -> Bool {
		return self.mapTable.object(forKey: url.cacheKey) != nil
	}
	
	open func remove(_ url: URL) {
		self.semaphore.wait()
		defer { self.semaphore.signal() }
		let key = url.cacheKey as NSString
		if let current = self.mapTable.object(forKey: key) as? CachedObjectInfo {
			self.currentSize -= Int64(current.size)
			self.mapTable.removeObject(forKey: key)
			self.diskCache?.remove(url)
		}
	}
	
	open func fetch<T: HoardDiskCachable>(for url: URL, moreRecentThan: Date? = nil) -> T? {
		if let info = self.mapTable.object(forKey: url.cacheKey) as? CachedObjectInfo {
			self.diskCache?.updateAccessedAtForRemoteURL(url)
			info.accessedAt = Date().timeIntervalSinceReferenceDate
			return info.object as? T
		}
		
		if let item: T = self.diskCache?.fetch(for: url, moreRecentThan: moreRecentThan) { return item }
		return nil
	}
	
	open func isCacheDataAvailable(for url: URL) -> Bool {
		if self.mapTable.object(forKey: url.cacheKey) != nil { return true }
		return self.diskCache?.isCacheDataAvailable(for: url) ?? false
	}
	
	open func prune(to size: Int64? = nil) {
		HoardState.addMaintenance {
			self.semaphore.wait()
			defer { self.semaphore.signal() }
			let limit = size ?? self.maxSize
			if self.currentSize < limit { return }
		
			let current = self.objectsSortedByLastAccess
			var index = 0
		
			while self.currentSize >= limit && index < current.count && current.count > 1 {
				let oldest = current[index]
				self.currentSize -= Int64(oldest.size)
				self.mapTable.removeObject(forKey: oldest.key as AnyObject?)
			}
			index += 1
		}
	}
	
	@objc func didReceiveMemoryWarning(note: Notification) {
		self.flushCache()
	}
	
	public func fetchImage(for url: URL, moreRecentThan: Date? = nil) -> UXImage? {
		if let image: UXImage = self.fetch(for: url, moreRecentThan: moreRecentThan) {
			return image
		}
		if let cached: UXImage = self.diskCache?.fetchImage(for: url, moreRecentThan: moreRecentThan) ?? self.fetch(for: url, moreRecentThan: moreRecentThan) {
			self.store(object: cached, from: url, skipDisk: true)
			return cached
		}
		return nil
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
		let object: HoardDiskCachable
		let size: Int
		var accessedAt: TimeInterval
		let key: NSString
		
		init(object obj: HoardDiskCachable, size sz: Int, key cacheKey: NSString, date: Date? = nil) {
			object = obj
			size = sz
			accessedAt = (date ?? Date()).timeIntervalSinceReferenceDate
			key = cacheKey
		}
	}
	
	public func prefetchImage(for url: URL) {
		_ = PendingImage.request(from: url, source: self, cache: self)
	}
}

extension Cache: HoardImageSource {
	public func generateImage(for url: URL) -> UXImage? {
		return self.fetchImage(for: url)
	}
	
	public func isFastImageGenerator(for url: URL) -> Bool {
		return self.hasData(for: url)
	}
}


