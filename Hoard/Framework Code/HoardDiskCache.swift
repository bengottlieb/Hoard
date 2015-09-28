//
//  DiskCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import MobileCoreServices
import ImageIO

extension Hoard {
	public class DiskCache: Cache {
		public enum StorageFormat: Int { case Data, JPEG, PNG
			var suggestedFileExtension: String? {
			switch self {
			case .Data: return nil
			case .JPEG: return "jpg"
			case .PNG: return "png"
			}}
		}
		
		public var storageFormat = StorageFormat.PNG
		public let baseURL: NSURL
		public let valid: Bool
		public var imageStorageQuality: CGFloat = 0.9
		var diskQueue: NSOperationQueue
		
		public init(URL: NSURL, type: StorageFormat = .PNG, description: String?) {
			baseURL = URL
			storageFormat = type
			diskQueue = NSOperationQueue()
			diskQueue.maxConcurrentOperationCount = 1
			diskQueue.qualityOfService = .Utility

			do {
				try NSFileManager.defaultManager().createDirectoryAtURL(URL, withIntermediateDirectories: true, attributes: nil)
				valid = true
			} catch let error {
				print("Unable to instantiate a disk cache at \(URL.path!): \(error)")
				valid = false
			}
			super.init(description: description)
			self.maxSize = self.optimalCacheSize()
			self.cacheLimitSize = Int64(Double(self.maxSize) * 1.25)
			self.diskOperation {
				self.currentSize = self.onDiskSize()
				if Hoard.debugLevel != .None {
					print("Current cache size: \(self.currentSize)")
				}
			}
		}
		
		func diskOperation(block: () -> Void) { self.diskQueue.addOperationWithBlock(block) }

		var cacheLimitSize: Int64 = 0		//what size do we start pruning the cache at?
		
		public override func nukeCache() {
			self.diskOperation {
				do {
					try NSFileManager.defaultManager().removeItemAtURL(self.baseURL)
					try NSFileManager.defaultManager().createDirectoryAtURL(self.baseURL, withIntermediateDirectories: true, attributes: nil)
					self.currentSize = 0
				} catch let error as NSError {
					print("Error while clearing Hoard cache: \(error)")
				}
			}
		}
		
		func dataForObject(target: NSObject?) -> NSData? {
			if let image = target as? UIImage {
				let data = NSMutableData()
				let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, "image/jpeg", nil)!.takeRetainedValue()

				if let destination = CGImageDestinationCreateWithData(data, uti, 1, nil), cgImage = image.CGImage {
					CGImageDestinationAddImage(destination, cgImage, nil)
					if !CGImageDestinationFinalize(destination) {
						return nil
					}
					return data
				}
				
				switch self.storageFormat {
				case .JPEG: return UIImageJPEGRepresentation(image, self.imageStorageQuality)
				case .PNG: return UIImagePNGRepresentation(image)
				case .Data: return nil
				}
			}
			if let storable = target as? HoardDiskCachable { return storable.hoardCacheData }
			return nil
		}
		
		override public func store(target: NSObject?, from URL: NSURL, skipDisk: Bool = false) {
			if let data = self.dataForObject(target) {
				self.storeData(data, from: URL, suggestedFileExtension: nil)
			}

		}

		public func storeData(data: NSData?, from URL: NSURL, suggestedFileExtension: String? = nil) {
			if !self.valid { return }
		
			self.diskOperation {
				if let data = data {
					let cacheURL = self.localURLForURL(URL)
					if data.writeToURL(cacheURL, atomically: true) {
						self.updateAccessedAt(cacheURL)
						self.currentSize += data.length
					}
					
					if self.currentSize > self.cacheLimitSize { self.prune() }
				} else {
					self.remove(URL)
				}
			}
		}
		
		func updateAccessedAtForRemoteURL(URL: NSURL) {
			self.diskOperation {
				let cachedURL = self.localURLForURL(URL)
				self.updateAccessedAt(cachedURL)
			}
		}
		
		public override func remove(URL: NSURL) {
			self.diskOperation {
				let cacheURL = self.localURLForURL(URL)
				
				self.currentSize -= NSFileManager.defaultManager().fileSizeAtURL(cacheURL)
				do {
					try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
				} catch let error {
					print("Failed to remove cached data for URL \(URL.path!): \(error)")
				}
			}
		}
		
		public func fetchData(from: NSURL) -> NSData? {
			let cachedURL = self.localURLForURL(from)
			if let data = NSData(contentsOfURL:  cachedURL) {
				Hoard.addMaintenanceBlock { self.updateAccessedAt(cachedURL) }
				return data
			}
			return nil
		}
		
		
		public override func isCacheDataAvailable(URL: NSURL) -> Bool {
			return NSFileManager.defaultManager().fileExistsAtPath(self.localURLForURL(URL).path ?? "/null")
		}
		
		public func localURLForURL(URL: NSURL) -> NSURL {
			return self.baseURL.URLByAppendingPathComponent(URL.cachedFilename(self.storageFormat.suggestedFileExtension))
		}
		
		override public func prune(size: Int64? = nil) {
			Hoard.addMaintenanceBlock {
				let files = self.buildFileList().sort(<)
				var size: Int64 = files.reduce(0, combine: { $0 + $1.size })
				let max = self.maxSize
				var index = 0
				
				while size > max && index < files.count {
					size -= files[index].remove()
					index++
				}
			}
		}
		
		func optimalCacheSize() -> Int64 {
			let systemAttributes = try? NSFileManager.defaultManager().attributesOfFileSystemForPath(NSHomeDirectory())
			let space = (systemAttributes?[NSFileSystemSize] as? NSNumber)?.longLongValue ?? 0
			
			return space / 10			//one tenth of available space
		}
		
		func buildFileList() -> [HoardFileInfo] {
			var files: [HoardFileInfo] = []
			
			do {
				let urls = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.baseURL, includingPropertiesForKeys: [NSFileSize], options: [.SkipsSubdirectoryDescendants, .SkipsHiddenFiles])
				for url in urls {
					files.append(HoardFileInfo(URL: url))
				}
			} catch {}
			
			return files
		}

		func onDiskSize() -> Int64 {
			var total: Int64 = 0
			do {
				let urls = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.baseURL, includingPropertiesForKeys: [NSFileSize], options: [.SkipsSubdirectoryDescendants, .SkipsHiddenFiles])
				for url in urls {
					total += NSFileManager.defaultManager().fileSizeAtURL(url)
				}
			} catch {}
			
			return total
		}
	}
}

let HoardLastAccessedAtDateAttributeName = "lastAccessed:com.standalone.hoard"

extension Hoard.DiskCache {
	func updateAccessedAt(URL: NSURL) {
		var seconds = NSDate().timeIntervalSinceReferenceDate
		let size = sizeof(NSTimeInterval)
		let path = URL.path!
		
		if !NSFileManager.defaultManager().fileExistsAtPath(path) { return }
		let result = setxattr(URL.path!, HoardLastAccessedAtDateAttributeName, &seconds, size, 0, 0)
		if result != 0 {
			print("Unable to set accessed at on \(path): \(result)")
		}
	}
	
	func accessedAt(URL: NSURL) -> NSDate? {
		var seconds: NSTimeInterval = 0
		let result = getxattr(URL.path!, HoardLastAccessedAtDateAttributeName, &seconds, sizeof(NSTimeInterval), 0, 0)
		
		if result == sizeof(NSTimeInterval) {
			return NSDate(timeIntervalSinceReferenceDate: NSTimeInterval(seconds))
		}

		return nil
	}
}

extension NSURL {
	public func cachedFilename(suggestedFileExtension: String? = nil) -> String {
		let basic = self.lastPathComponent ?? "--"
		let nameOnly = (basic as NSString).stringByDeletingPathExtension
		let currentExt = self.pathExtension ?? ""
		var ext = currentExt.isEmpty ? (suggestedFileExtension ?? "dat") : currentExt
		if let suggestion = suggestedFileExtension { ext = suggestion }
		
		return "\(self.hash)-" + nameOnly + "." + ext
	}
}

class HoardFileInfo: CustomStringConvertible, Comparable {
	let URL: NSURL
	let size: Int64
	let accessedAt: NSTimeInterval
	init(URL file: NSURL) {
		URL = file
		let path = file.path!
		var seconds: NSTimeInterval = 0
		let result = getxattr(path, HoardLastAccessedAtDateAttributeName, &seconds, sizeof(NSTimeInterval), 0, 0)
		accessedAt = result == sizeof(NSTimeInterval) ? seconds : NSTimeInterval(0)
		size = NSFileManager.defaultManager().fileSizeAtURL(URL)
	}
	
	func remove() -> Int64 {
		do {
			try NSFileManager.defaultManager().removeItemAtURL(self.URL)
			return self.size
		} catch {}
		return 0
	}
	
	var sizeString: String {
		if self.size < 1024 { return "\(self.size) b" }
		if self.size < 1024 * 1024 { return "\(self.size / 1024) KB" }
		return "\(self.size / (1024 * 1024)) MB"
	}
	var description: String { return "\(self.accessedAt) / \(self.URL.lastPathComponent!) / \(self.sizeString)" }
}

extension NSFileManager {
	func fileSizeAtURL(URL: NSURL) -> Int64 {
		do {
			let info = try NSFileManager.defaultManager().attributesOfItemAtPath(URL.path!)
			return Int64(info[NSFileSize] as? Int ?? 0)
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