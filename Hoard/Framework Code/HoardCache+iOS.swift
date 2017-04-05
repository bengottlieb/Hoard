//
//  DiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import ImageIO
import CrossPlatformKit

public extension Cache {
	public func fetchImage(for url: URL) -> UXImage? {
		if let image = self.fetch(for: url) as? UXImage {
			return image
		}
		if let cached = self.diskCache?.fetchImage(for: url) ?? self.fetch(for: url) as? UXImage {
			self.store(object: cached, from: url, skipDisk: true)
			return cached
		}
		return nil
	}
}

public extension DiskCache {
	public override func fetchImage(for url: URL) -> UXImage? {
		let localURL = self.localURLForURL(url)
		let path = localURL.path
		
		if FileManager.default.fileExists(atPath: path), let image = UXImage.decompressedImage(with: localURL) {
			return image
		}
		
		if let data = self.fetchData(for: url), let image = UXImage.decompressedImage(with: data) {
			return image
		}
		return nil
	}
	
}

public extension UXImage {
	public class func decompressedImage(with data: Data) -> UXImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return UXImage(cgImage: cgImage)
		}
		
		return nil
	}

	@nonobjc
	public class func decompressedImage(with url: URL) -> UXImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let data = try? Data(contentsOf: url), let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return UXImage(cgImage: cgImage)
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
