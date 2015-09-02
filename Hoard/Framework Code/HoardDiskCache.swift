//
//  HoardDiskCache.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class HoardDiskCache: HoardCache {
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
	
	public init(URL: NSURL, type: StorageFormat = .PNG) {
		baseURL = URL
		storageFormat = type
		do {
			try NSFileManager.defaultManager().createDirectoryAtURL(URL, withIntermediateDirectories: true, attributes: nil)
			valid = true
		} catch let error {
			print("Unable to instantiate a disk cache at \(URL.path!): \(error)")
			valid = false
		}
	}
	
	public override func nukeCache() {
		Hoard.addMaintenanceBlock {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(self.baseURL)
				try NSFileManager.defaultManager().createDirectoryAtURL(self.baseURL, withIntermediateDirectories: true, attributes: nil)
			} catch let error as NSError {
				print("Error while clearing Hoard cache: \(error)")
			}
		}
	}
	
	public func storeData(data: NSData?, from URL: NSURL, suggestedFileExtension: String? = nil) -> Bool {
		if !self.valid { return false }
	
		if let data = data {
			let cacheURL = self.localURLForURL(URL)
			return data.writeToURL(cacheURL, atomically: true)
		} else {
			self.remove(URL)
		}
		
		return true
	}
	
	public override func remove(URL: NSURL) {
		let cacheURL = self.localURLForURL(URL)
		
		do {
			try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
		} catch let error {
			print("Failed to remove cached data for URL \(URL.path!): \(error)")
		}
	}
	
	public func fetchData(from: NSURL) -> NSData? {
		let data = NSData(contentsOfURL:  self.localURLForURL(from))
		return data
	}
	
	
	public override func isCacheDataAvailable(URL: NSURL) -> Bool {
		return NSFileManager.defaultManager().fileExistsAtPath(self.localURLForURL(URL).path ?? "/null")
	}
	
	public func localURLForURL(URL: NSURL) -> NSURL {
		return self.baseURL.URLByAppendingPathComponent(URL.cachedFilename(self.storageFormat.suggestedFileExtension))
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