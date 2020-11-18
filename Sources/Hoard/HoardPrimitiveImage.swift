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
	}
#else
	import AppKit
	extension NSImage {
		public var suggestedFileExtension: String { return "png" }
	}
	
#endif
