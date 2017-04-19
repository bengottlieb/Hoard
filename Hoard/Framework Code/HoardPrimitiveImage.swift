//
//  UXImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 1/5/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation
import CrossPlatformKit

#if os(iOS)
	import UIKit
	extension UIImage {
		public var suggestedFileExtension: String { return "png" }
		public class func withJPEGData(_ data: Data?) -> UIImage? {
			guard let data = data else { return nil }
			return UIImage(data: data)
		}
	}
	
	extension Bundle {
		public func image(named name: String) -> UIImage? {
			return UIImage(named: name, in: self, compatibleWith: nil)
		}
	}
#else
	import AppKit
	extension NSImage {
		public var suggestedFileExtension: String { return "png" }
		
		public convenience init(cgImage: CGImage) {
			self.init(cgImage: cgImage, size: NSSize.zero)
		}
	}
	
	extension Bundle {
		public func image(named name: String) -> NSImage? {
			return self.image(forResource: name)
		}
	}
#endif
