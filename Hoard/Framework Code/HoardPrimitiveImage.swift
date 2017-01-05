//
//  HoardPrimitiveImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 1/5/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation

#if os(iOS)
	import UIKit
	public typealias HoardPrimitiveImage = UIImage
	
	extension UIImage {
		public var suggestedFileExtension: String { return "png" }
		func jpegRepresentation(_ quality: CGFloat) -> Data? { return UIImageJPEGRepresentation(self, quality) }
		var pngRepresentation: Data? { return UIImagePNGRepresentation(self) }
	}
#else
	import AppKit
	public typealias HoardPrimitiveImage = NSImage

	extension NSImage {
		public var suggestedFileExtension: String { return "png" }
	}
#endif

