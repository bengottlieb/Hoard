//
//  HoardDiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

public extension HoardCache {
	public func storeImage(image: UIImage?, from URL: NSURL) -> Bool {
		if !self.store(image, from: URL) { return false }
		
		if let disk = self.diskCache where !disk.storeImage(image, from: URL) {
			return false
		}
		return true
	}
	
	public func fetchImage(from: NSURL) -> UIImage? {
		if let image = self.fetch(from) as? UIImage {
			return image
		}
		if let cached = self.diskCache?.fetchImage(from) ?? self.fetch(from) as? UIImage {
			self.cache.setObject(cached, forKey: from.cacheKey, cost: cached.hoardCacheCost)
			return cached
		}
		return nil
	}
}

public extension HoardDiskCache {
	public override func storeImage(image: UIImage?, from URL: NSURL) -> Bool {
		
		if let image = image {
			let data: NSData?

			switch self.storageFormat {
			case .JPEG: data = UIImageJPEGRepresentation(image, self.imageStorageQuality)
			case .PNG: data = UIImagePNGRepresentation(image)
			case .Data: return false
			}
			
			return self.storeData(data, from: URL, suggestedFileExtension: nil)
		}
		return false
	}
	
	public override func fetchImage(from: NSURL) -> UIImage? {
		if let data = self.fetchData(from) {
			return UIImage(data: data)
		}
		return nil
	}
	
}

public extension UIImage {
	public var hoardCacheCost: Int { return Int(self.size.width) * Int(self.size.height) }
}