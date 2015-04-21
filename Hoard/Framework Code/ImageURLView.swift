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
				self.tempImageView?.removeFromSuperview()
				self.pendingImage = Hoard.cache.requestImageURL(url, completion: { image, error in
					if let error = error {
						println("Error while downloading image from \(url): \(error)")
					}
					if url == tempURL && image != nil {
						if self.revealAnimationDuration > 0.0 {
							self.tempImageView = UIImageView(frame: self.bounds)
							
							self.tempImageView?.contentMode = self.contentMode
							self.tempImageView?.image = image
							self.tempImageView?.alpha = 0.0
							
							self.addSubview(self.tempImageView!)
							
							UIView.animateWithDuration(self.revealAnimationDuration, animations: { self.tempImageView?.alpha = 1.0 }, completion: { completed in
								self.image = image
								self.tempImageView?.removeFromSuperview()
							})
						} else {
							self.image = image
						}
						self.pendingImage = nil
					}
					if image == nil {
						println("missing image: \(tempURL)")
					}
				})
				self.image = self.pendingImage?.image
			}
		}
	}
	
	public func setURL(url: NSURL, placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.URL = url
		if self.image == nil { self.image = placeholder }
		self.revealAnimationDuration = duration
	}
	
	
	public var revealAnimationDuration = 0.2
	public var pendingImage: PendingImage?
	
	var tempImageView: UIImageView?
	
}
