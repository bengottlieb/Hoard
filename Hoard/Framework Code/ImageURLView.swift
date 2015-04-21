//
//  ImageURLView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

public class ImageURLView: UIImageView {
	public var URL: NSURL? {
		didSet {
			self.pendingImage?.cancel()
			
			if let url = self.URL {
				var tempURL = url
				var pending = Hoard.cache.requestImageURL(url, completion: { image, error in
					if url == tempURL {
						self.image = image
						self.pendingImage = nil
					}
				})
			}
		}
	}
	
	public var pendingImage: PendingImage?
	
	
}
