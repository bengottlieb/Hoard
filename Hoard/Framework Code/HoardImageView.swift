//
//  HoardImageView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

var s_currentImageView: HoardImageView?


public class HoardImageView: UIImageView {
	public var useDeviceOrientation = false { didSet { self.updateDeviceOrientationNotifications() }}
	public var tapForFullScreen = false { didSet { self.updateTapForFullScren() }}
	
	deinit {
		println("deinit imageView")
	}
	
	public var URL: NSURL? {
		didSet {
			if oldValue == self.URL && (self.image != nil || self.pendingImage != nil)  { return }
			self.pendingImage?.cancel()
			
			if let url = self.URL {
				var tempURL = url
				self.tempImageView?.removeFromSuperview()
				self.pendingImage = Hoard.cache.requestImageURL(url, completion: { image, error in
					if let error = error {
						println("Error while downloading image from \(url): \(error)")
					}
					if self.URL == tempURL && image != nil {
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
				if self.window != nil {
					self.image = self.pendingImage?.image
				}
			}
		}
	}
	
	public func setURL(url: NSURL?, placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.URL = url
		
		self.placeholder = placeholder
		if self.image == nil { self.image = placeholder }
		self.revealAnimationDuration = duration * (Hoard.debugging ? 10.0 : 1.0)
	}
	
	var placeholder: UIImage?
	
	public var revealAnimationDuration = 0.0 * (Hoard.debugging ? 10.0 : 1.0)
	public var pendingImage: PendingImage?
	
	var tempImageView: UIImageView?
	
	//=============================================================================================
	//MARK: Full screen
	
	func updateDeviceOrientationNotifications() {
		if self.useDeviceOrientation {
			self.addAsObserver(UIDeviceOrientationDidChangeNotification, selector: "orientationChanged:", object: nil)
		} else {
			NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
		}
	}
	
	var fullScreenView: HoardImageGalleryView?
	
	var parentGallery: HoardImageGalleryView?
	
	func makeFullScreen() {
		
		if let parent = UIWindow.rootWindow()?.rootViewController {
			s_currentImageView = self
			var host = parent.view
			var newFrame = self.convertRect(self.bounds, toView: host)
			self.fullScreenView = HoardImageGalleryView(frame: newFrame)
			
			if let parent = self.parentGallery {
				self.fullScreenView!.setURLs(parent.imageURLs, placeholder: self.placeholder)
				self.fullScreenView!.setCurrentIndex(parent.imageURLs.indexOf(self.URL!) ?? 0, animated: false)
			} else {
				self.fullScreenView?.setURLs(self.parentGallery?.imageURLs ?? [self.URL!], placeholder: self.placeholder)
			}
			self.fullScreenView?.backgroundColor = UIColor.blackColor()
			//self.fullScreenView?.image = self.image
			self.fullScreenView?.contentMode = .ScaleAspectFit
			self.fullScreenView?.userInteractionEnabled = true
			self.fullScreenView?.clipsToBounds = true
			self.fullScreenView?.alpha = 1.0
			self.fullScreenView?.autoresizingMask = .FlexibleWidth | .FlexibleHeight
			host.addSubview(self.fullScreenView!)
			host.bringSubviewToFront(self.fullScreenView!)

			UIView.animateWithDuration(0.25 * (Hoard.debugging ? 1.0 : 1.0), delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
				self.alpha = 0.0
				self.fullScreenView?.alpha = 1.0
				self.fullScreenView?.frame = host.frame
			}, completion: { completed in })
			self.fullScreenView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "dismissFullScreen:"))
		//	self.fullScreenView?.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: "share:"))
		}
	}
	
	func dismissFullScreen(recog: UITapGestureRecognizer) {
		if s_currentImageView == self { s_currentImageView = nil }
		self.parentGallery?.setCurrentIndex(self.fullScreenView!.currentIndex, animated: false)
		if let parent = UIViewController.frontmostController() {
			var host = parent.view
			var newFrame = self.convertRect(self.bounds, toView: host)
			UIView.animateWithDuration(0.25 * (Hoard.debugging ? 1.0 : 1.0), delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
				self.alpha = 1.0
				self.fullScreenView?.alpha = 0.0
				if let superview = self.superview { self.fullScreenView?.frame = newFrame }
				}, completion: { completed in
					self.alpha = 1.0
					self.fullScreenView?.removeFromSuperview()
					self.fullScreenView = nil
			})
		}
	}
	
	func orientationChanged(note: NSNotification) {
		var frame = UIScreen.mainScreen().bounds
		var transform = CGAffineTransformIdentity
		
		switch (UIDevice.currentDevice().orientation) {
		case .LandscapeLeft:
			transform = CGAffineTransformMakeRotation(CGFloat(M_PI / 2.0))
			frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
			
		case .LandscapeRight:
			transform = CGAffineTransformMakeRotation(CGFloat(-M_PI / 2.0))
			frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
			
		default: break
			
		}
		UIView.animateWithDuration(0.2 * (Hoard.debugging ? 10.0 : 1.0), animations: {
			self.fullScreenView?.bounds = frame
			self.fullScreenView?.transform = transform
		})
	}
	
	
	////=============================================================================================
	//MARK:

	var tapRecognizer: UITapGestureRecognizer?
	func updateTapForFullScren() {
		if self.tapForFullScreen {
			if self.tapRecognizer == nil {
				self.userInteractionEnabled = true
				self.tapRecognizer = UITapGestureRecognizer(target: self, action: "imageTapped:")
				self.addGestureRecognizer(self.tapRecognizer!)
			}
		} else {
			if let recog = self.tapRecognizer {
				self.removeGestureRecognizer(recog)
				self.tapRecognizer = nil
			}
		}
	}
	
	func imageTapped(recog: UITapGestureRecognizer) {
		var location = recog.locationInView(self)
		if let tapped = self.hitTest(location, withEvent: nil) as? HoardImageView {
			tapped.makeFullScreen()
		}
	}
	


}
