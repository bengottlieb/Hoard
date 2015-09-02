//
//  HoardDiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import UIKit
import ImageIO

public extension HoardCache {
	public func storeImage(image: UIImage?, from URL: NSURL) -> Bool {
		self.store(image, from: URL)
		
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
			self.store(cached, from: from, skipDisk: true)
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
		let localURL = self.localURLForURL(from)
		if let path = localURL.path where NSFileManager.defaultManager().fileExistsAtPath(path), let image = UIImage.decompressedImageWithURL(localURL) {
			return image
		}
		
		if let data = self.fetchData(from), image = UIImage.decompressedImageWithData(data) {
			return image
		}
		return nil
	}
	
}

extension UIImage: HoardCacheStoredObject {
	public var hoardCacheCost: Int { return Int(self.size.width) * Int(self.size.height) }
}

public extension UIImage {
	public class func decompressedImageWithData(data: NSData) -> UIImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data, nil), cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) {
			return UIImage(CGImage: cgImage)
		}
		
		return nil
	}
	
	public class func decompressedImageWithURL(url: NSURL) -> UIImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithURL(url, nil), cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) {
			return UIImage(CGImage: cgImage)
		}
		
		return nil
	}

	convenience public init?(decompressableData data: NSData) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data, nil), cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) {
			self.init(CGImage: cgImage)
		}
		return nil
	}

	convenience public init?(decompressableURL url: NSURL) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithURL(url, nil), cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) {
			self.init(CGImage: cgImage)
		}
		return nil
	}
}