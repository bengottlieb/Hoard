//
//  UIImage+Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/28/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

public extension UIImage {
	public var data: NSData? {
		return UIImagePNGRepresentation(self)
	}
	
	public var suggestedFileExtension: String {
		return "png"
	}
}