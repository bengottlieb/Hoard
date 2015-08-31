//
//  HoardDiskCache+iOS.swift
//  Hoard
//
//  Created by Ben Gottlieb on 8/28/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

public extension HoardDiskCache {
	public func storeImage(image: UIImage?, from URL: NSURL) -> Bool {
		
		if let image = image {
			let data: NSData?

			switch self.storageFormat {
			case .JPEG: data = UIImageJPEGRepresentation(image, self.imageStorageQuality)
			case .PNG: data = UIImagePNGRepresentation(image)
			case .Data: return false
			}
			
			return self.store(data, from: URL)
		}
		return false
	}
	
	public func fetchImage(from: NSURL) -> UIImage? {
		if let data = self.fetch(from) {
			return UIImage(data: data)
		}
		return nil
	}
	
}