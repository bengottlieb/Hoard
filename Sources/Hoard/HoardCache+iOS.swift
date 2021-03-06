//
//  DiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import ImageIO
import CrossPlatformKit

public extension Cache {
}

public extension DiskCache {
	
}

public extension UXImage {
	class func decompressedImage(with data: Data) -> UXImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return UXImage(cgImage: cgImage)
		}
		
		return nil
	}

	@nonobjc
	class func decompressedImage(with url: URL) -> UXImage? {
		let options = [String(kCGImageSourceShouldCache): true]
		if let data = try? Data(contentsOf: url), let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			return UXImage(cgImage: cgImage)
		}
		
		return nil
	}

	convenience init?(decompressableData data: Data) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			self.init(cgImage: cgImage)
		}
		return nil
	}

	convenience init?(decompressableURL url: URL) {
		let options = [String(kCGImageSourceShouldCache): true]
		if let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary?) {
			self.init(cgImage: cgImage)
		}
		return nil
	}
}
