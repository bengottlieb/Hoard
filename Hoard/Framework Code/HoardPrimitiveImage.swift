//
//  UXImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 1/5/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

#if os(iOS)
	import UIKit
	public typealias UXImage = UIImage
	public typealias UXRect = CGRect
	
	extension UIImage {
		public var suggestedFileExtension: String { return "png" }
		public class func withJPEGData(_ data: Data?) -> UIImage? {
			guard let data = data else { return nil }
			return UIImage(data: data)
		}
		
		public func jpegData(_ quality: CGFloat) -> Data? {
			return UIImageJPEGRepresentation(self, 0.9)
		}
		
		public func pngData() -> Data? {
			return UIImagePNGRepresentation(self)
		}
	}
	
	extension Bundle {
		public func image(named name: String) -> UIImage? {
			return UIImage(named: name, in: self, compatibleWith: nil)
		}
	}
#else
	import AppKit
	public typealias UXImage = NSImage
	public typealias UXRect = NSRect
	
	extension NSImage {
		public var suggestedFileExtension: String { return "png" }
		public func jpegData(_ quality: CGFloat) -> Data? {
			if let tiff = self.tiffRepresentation {
				let rep = NSBitmapImageRep(data: tiff)
				return rep?.representation(using: .JPEG, properties: [NSImageCompressionFactor: quality])
			}
			return nil
		}
		public func pngData() -> Data? {
			if let tiff = self.tiffRepresentation {
				let rep = NSBitmapImageRep(data: tiff)
				return rep?.representation(using: .PNG, properties: [NSImageCompressionFactor: quality])
			}
			return nil
		}
  
		public class func withJPEGData(_ data: Data?) -> NSImage? {
			guard let data = data else { return nil }
			return NSImage(data: data)
		}
	}
	
	extension Bundle {
		public func image(named name: String) -> NSImage? {
			return self.image(forResource: name)
		}
	}
#endif
