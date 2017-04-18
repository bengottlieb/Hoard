//
//  DiskCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
#if os(iOS)
	import MobileCoreServices
#endif
import ImageIO
import CrossPlatformKit

open class DiskCache: Cache {
	public enum StorageFormat: Int { case data, jpeg, png
		var suggestedFileExtension: String? {
		switch self {
		case .data: return nil
		case .jpeg: return "jpg"
		case .png: return "png"
		}}
	}
	
	open var storageFormat = StorageFormat.png
	open let baseURL: URL
	open let valid: Bool
	open var imageStorageQuality: CGFloat = 0.9
	var diskQueue: OperationQueue
	
	public init(URL: Foundation.URL, type: StorageFormat = .png, description: String?) {
		baseURL = URL
		storageFormat = type
		diskQueue = OperationQueue()
		diskQueue.maxConcurrentOperationCount = 1
		diskQueue.qualityOfService = .utility

		do {
			try FileManager.default.createDirectory(at: URL, withIntermediateDirectories: true, attributes: nil)
			valid = true
		} catch let error {
			print("Unable to instantiate a disk cache at \(URL.path): \(error)")
			valid = false
		}
		super.init(description: description)
		self.maxSize = self.optimalCacheSize()
		self.cacheLimitSize = Int64(Double(self.maxSize) * 1.25)
		self.performDiskOperation {
			self.currentSize = self.onDiskSize()
			if HoardState.debugLevel != .none {
				print("Current cache size: \(self.currentSize)")
			}
		}
	}
	
	func performDiskOperation(_ block: @escaping () -> Void) { self.diskQueue.addOperation(block) }

	var cacheLimitSize: Int64 = 0		//what size do we start pruning the cache at?
	
	func clearOut() {
		self.performDiskOperation {
			do {
				try FileManager.default.removeItem(at: self.baseURL)
				try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true, attributes: nil)
				self.currentSize = 0
			} catch let error as NSError {
				print("Error while clearing Hoard cache: \(error)")
			}
		}
	}
	
	func data(for target: HoardDiskCachable?) -> Data? {
		if let image = target as? UXImage {
			let data = NSMutableData()
			let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, "image/jpeg" as CFString, nil)!.takeRetainedValue()

			#if os(iOS)
				if let destination = CGImageDestinationCreateWithData(data, uti, 1, nil), let cgImage = image.cgImage {
					CGImageDestinationAddImage(destination, cgImage, nil)
					if !CGImageDestinationFinalize(destination) {
						return nil
					}
					return data as Data
				}
			#endif
			
			switch self.storageFormat {
			case .jpeg: return image.jpegData(self.imageStorageQuality)
			case .png: return image.pngData()
			case .data: return nil
			}
		}
		return target?.hoardCacheData
	}
	
	open func storeData(_ data: Data?, from URL: Foundation.URL, suggestedFileExtension: String? = nil) {
		if !self.valid { return }
	
		self.performDiskOperation {
			if let data = data {
				let cacheURL = self.localURLForURL(URL)
				if (try? data.write(to: cacheURL, options: [.atomic])) != nil {
					self.updateStoredAt(cacheURL)
					self.currentSize += Int64(data.count)
				}
				
				if self.currentSize > self.cacheLimitSize { self.prune() }
			} else {
				self.remove(URL)
			}
		}
	}
	
	func updateAccessedAtForRemoteURL(_ URL: Foundation.URL) {
		self.performDiskOperation {
			let cachedURL = self.localURLForURL(URL)
			self.updateAccessedAt(cachedURL)
		}
	}
	
	open func fetchData(for url: URL, moreRecentThan: Date? = nil) -> Data? {
		let cachedURL = self.localURLForURL(url)
		
		if let date = moreRecentThan, let storedAt = self.storedAt(cachedURL), storedAt < date { return nil }
		
		if let data = try? Data(contentsOf: cachedURL) {
			HoardState.addMaintenance { self.updateAccessedAt(cachedURL) }
			return data
		}
		return nil
	}
	
	
	open func localURLForURL(_ URL: Foundation.URL) -> Foundation.URL {
		return self.baseURL.appendingPathComponent(URL.cachedFilename(self.storageFormat.suggestedFileExtension))
	}
	
	func optimalCacheSize() -> Int64 {
		let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
		let space = (systemAttributes?[FileAttributeKey.systemSize] as? NSNumber)?.int64Value ?? 0
		
		return space / 10			//one tenth of available space
	}
	
	func buildFileList() -> [HoardFileInfo] {
		var files: [HoardFileInfo] = []
		
		do {
			let urls = try FileManager.default.contentsOfDirectory(at: self.baseURL, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
			for url in urls {
				files.append(HoardFileInfo(URL: url))
			}
		} catch {}
		
		return files
	}

	func onDiskSize() -> Int64 {
		var total: Int64 = 0
		do {
			let urls = try FileManager.default.contentsOfDirectory(at: self.baseURL, includingPropertiesForKeys: [URLResourceKey.fileSizeKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
			for url in urls {
				total += FileManager.default.fileSizeAtURL(url)
			}
		} catch {}
		
		return total
	}

	public override func nuke() {
		self.clearOut()
	}

	override open func store(object: HoardDiskCachable?, from URL: Foundation.URL, skipDisk: Bool = false) {
		if let data = self.data(for: object) {
			self.storeData(data, from: URL, suggestedFileExtension: nil)
		}
	}

	open override func remove(_ URL: Foundation.URL) {
		self.performDiskOperation {
			let cacheURL = self.localURLForURL(URL)
			
			self.currentSize -= FileManager.default.fileSizeAtURL(cacheURL)
			do {
				try FileManager.default.removeItem(at: cacheURL)
			} catch let error {
				print("Failed to remove cached data for URL \(URL.path): \(error)")
			}
		}
	}

	open override func isCacheDataAvailable(for url: URL) -> Bool {
		return FileManager.default.fileExists(atPath: self.localURLForURL(url).path)
	}
	
	override open func prune(to size: Int64? = nil) {
		HoardState.addMaintenance {
			let files = self.buildFileList().sorted(by: <)
			var size: Int64 = files.reduce(0, { $0 + $1.size })
			let max = self.maxSize
			var index = 0
			
			while size > max && index < files.count {
				size -= files[index].remove()
				index += 1
			}
		}
	}
	
}

let HoardLastAccessedAtDateAttributeName = "lastAccessed:com.standalone.hoard"
let HoardLastStoredAtDateAttributeName = "lastStored:com.standalone.hoard"

extension DiskCache {
	func updateAccessedAt(_ URL: Foundation.URL) {
		var seconds = Date().timeIntervalSinceReferenceDate
		let size = MemoryLayout<TimeInterval>.size
		let path = URL.path
		
		if !FileManager.default.fileExists(atPath: path) { return }
		let result = setxattr(URL.path, HoardLastAccessedAtDateAttributeName, &seconds, size, 0, 0)
		if result != 0 {
			print("Unable to set accessed at on \(path): \(result)")
		}
	}
	
	func accessedAt(_ URL: Foundation.URL) -> Date? {
		var seconds: TimeInterval = 0
		let result = getxattr(URL.path, HoardLastAccessedAtDateAttributeName, &seconds, MemoryLayout<TimeInterval>.size, 0, 0)
		
		if result == MemoryLayout<TimeInterval>.size {
			return Date(timeIntervalSinceReferenceDate: TimeInterval(seconds))
		}
		
		return nil
	}

	func updateStoredAt(_ URL: Foundation.URL) {
		var seconds = Date().timeIntervalSinceReferenceDate
		let size = MemoryLayout<TimeInterval>.size
		let path = URL.path
		
		if !FileManager.default.fileExists(atPath: path) { return }
		let result = setxattr(URL.path, HoardLastStoredAtDateAttributeName, &seconds, size, 0, 0)
		if result != 0 {
			print("Unable to set stored at on \(path): \(result)")
		}
	}
	
	func storedAt(_ URL: Foundation.URL) -> Date? {
		var seconds: TimeInterval = 0
		let result = getxattr(URL.path, HoardLastStoredAtDateAttributeName, &seconds, MemoryLayout<TimeInterval>.size, 0, 0)
		
		if result == MemoryLayout<TimeInterval>.size {
			return Date(timeIntervalSinceReferenceDate: TimeInterval(seconds))
		}
		
		return nil
	}
}

extension Foundation.URL {
	public func cachedFilename(_ suggestedFileExtension: String? = nil) -> String {
		let basic = self.lastPathComponent
		let nameOnly = (basic as NSString).deletingPathExtension
		let currentExt = self.pathExtension
		var ext = currentExt.isEmpty ? (suggestedFileExtension ?? "dat") : currentExt
		if let suggestion = suggestedFileExtension { ext = suggestion }
		
		return "\((self as NSURL).hash)-" + nameOnly + "." + ext
	}
}

class HoardFileInfo: CustomStringConvertible, Comparable {
	let URL: Foundation.URL
	let size: Int64
	let accessedAt: TimeInterval
	init(URL file: Foundation.URL) {
		URL = file
		let path = file.path
		var seconds: TimeInterval = 0
		let result = getxattr(path, HoardLastAccessedAtDateAttributeName, &seconds, MemoryLayout<TimeInterval>.size, 0, 0)
		accessedAt = result == MemoryLayout<TimeInterval>.size ? seconds : TimeInterval(0)
		size = FileManager.default.fileSizeAtURL(URL)
	}
	
	func remove() -> Int64 {
		do {
			try FileManager.default.removeItem(at: self.URL)
			return self.size
		} catch {}
		return 0
	}
	
	var sizeString: String {
		if self.size < 1024 { return "\(self.size) b" }
		if self.size < 1024 * 1024 { return "\(self.size / 1024) KB" }
		return "\(self.size / (1024 * 1024)) MB"
	}
	var description: String { return "\(self.accessedAt) / \(self.URL.lastPathComponent) / \(self.sizeString)" }
}

extension FileManager {
	func fileSizeAtURL(_ URL: Foundation.URL) -> Int64 {
		do {
			let info = try FileManager.default.attributesOfItem(atPath: URL.path)
			return Int64(info[FileAttributeKey.size] as? Int ?? 0)
		} catch {
			return 0
		}
	}
}

func <(lhs: HoardFileInfo, rhs: HoardFileInfo) -> Bool {
	return lhs.accessedAt < rhs.accessedAt
}

func ==(lhs: HoardFileInfo, rhs: HoardFileInfo) -> Bool {
	return lhs.URL == rhs.URL
}
