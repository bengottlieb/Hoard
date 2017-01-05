//
//  DiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import ImageIO

public extension Cache {
	public func fetchImage(_ from: URL) -> HoardPrimitiveImage? {
		if let image = self.fetch(from) as? HoardPrimitiveImage {
			return image
		}
		if let cached = self.diskCache?.fetchImage(from) ?? self.fetch(from) as? HoardPrimitiveImage {
			self.store(cached, from: from, skipDisk: true)
			return cached
		}
		return nil
	}
}

public extension DiskCache {
	public override func fetchImage(_ from: URL) -> HoardPrimitiveImage? {
		let localURL = self.localURLForURL(from)
		let path = localURL.path
		
		if FileManager.default.fileExists(atPath: path), let image = HoardPrimitiveImage.decompressedImageWithURL(localURL) {
			return image
		}
		
		if let data = self.fetchData(from), let image = HoardPrimitiveImage.decompressedImageWithData(data) {
			return image
		}
		return nil
	}
	
}

extension HoardPrimitiveImage: CacheStoredObject {
	public var hoardCacheSize: Int { return Int(self.size.width) * Int(self.size.height) }
}

public extension HoardPrimitiveImage {
	public class func decompressedImageWithData(_ data: Data) -> HoardPrimitiveImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return HoardPrimitiveImage(cgImage: cgImage)
		}
		
		return nil
	}
	
	public class func decompressedImageWithURL(_ url: URL) -> HoardPrimitiveImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let data = try? Data(contentsOf: url), let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return HoardPrimitiveImage(cgImage: cgImage)
		}
		
		return nil
	}

	convenience public init?(decompressableData data: Data) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			self.init(cgImage: cgImage)
		}
		return nil
	}

	convenience public init?(decompressableURL url: URL) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			self.init(cgImage: cgImage)
		}
		return nil
	}
}
