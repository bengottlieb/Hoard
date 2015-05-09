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
		NSNotificationCenter.defaultCenter().removeObserver(self)
		println("deinit imageView")
	}
	
	var imageURL: NSURL?
	public var URL: NSURL? {
		set {
			if newValue == self.displayedURL && (self.image != nil || self.pendingImage != nil)  { return }
			if let pendingURL = self.pendingImage?.URL, actualURL = self.URL where actualURL == pendingURL { return }
			self.setURL(newValue)
		}
		get { return self.imageURL }
	}
	
	public func setURL(url: NSURL?, placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.imageURL = url
		
		self.pendingImage?.cancel()
		
		if let url = url {
			if Hoard.debugging { self.backgroundColor = UIColor(red: CGFloat(url.absoluteString!.hash % 255) / 255.0, green: CGFloat(url.absoluteString!.hash % 253) / 255.0, blue: CGFloat(url.absoluteString!.hash % 254) / 255.0, alpha: 1.0) }
			var tempURL = url
			self.displayedURL = nil
			self.tempImageView?.removeFromSuperview()
			self.pendingImage = Hoard.cache.requestImageURL(url, completion: { [unowned self] image, error, fromCache in
				if let error = error {
					println("Error while downloading image from \(url): \(error)")
				}
				var gallery = self.parentGallery
				var view = self
				
				if let image = image {
					self.displayedURL = url

					if self.imageURL == tempURL && image != self.image {
						//println("received image: \(self.URL) at \(self.galleryIndex)")
						if self.revealAnimationDuration > 0.0 && !fromCache {
							var tempView = UIImageView(frame: self.bounds)
							self.tempImageView = tempView
							
							self.tempImageView?.contentMode = self.contentMode
							self.tempImageView?.image = image
							self.tempImageView?.alpha = 0.0
							
							self.addSubview(self.tempImageView!)
							
							UIView.animateWithDuration(self.revealAnimationDuration, animations: { self.tempImageView?.alpha = 1.0 }, completion: { completed in
								if let imageURL = self.imageURL where imageURL == url {
									self.image = image
								}
								tempView.removeFromSuperview()
							})
						} else {
							self.image = image
						}
						self.pendingImage = nil
					}
				} else {
					self.displayedURL = nil
					self.image = nil
					println("missing image: \(tempURL)")
				}
			})
			
			if let image = self.pendingImage?.image, url = self.pendingImage?.URL where (self.displayedURL == nil || self.displayedURL != url) {
				self.image = image
				self.displayedURL = url
			}
		}

		
		self.placeholder = placeholder
		if self.image == nil { self.image = placeholder }
		self.revealAnimationDuration = duration * (Hoard.debugging ? 10.0 : 1.0)
	}
	
	func prepareForReuse() {
		self.displayedURL = nil
		self.imageURL = nil
		self.image = nil
		self.backgroundColor = UIColor.clearColor()
		self.tempImageView?.removeFromSuperview()
		self.tempImageView = nil
	}
	
	var displayedURL: NSURL? { didSet {
		if let url = self.displayedURL {
			self.urlLabel?.text = url.absoluteString
		} else {
			self.backgroundColor = UIColor.orangeColor()
		}
	}}
	var placeholder: UIImage?
	
	var urlLabel: UILabel?
	
	public var revealAnimationDuration = 0.2 * (Hoard.debugging ? 10.0 : 1.0)
	public var pendingImage: PendingImage?
	
	var tempImageView: UIImageView?
	
	var imageLayer: CALayer!
	var imageView: UIImageView!
	var image2: UIImage? {
		didSet {
			if let image = self.image {
				if self.imageView == nil {
					self.imageView = UIImageView(frame: self.frameForImageSize(image.size))
					self.addSubview(self.imageView)
				} else {
					self.imageView.frame = self.frameForImageSize(image.size)
				}
				self.imageView.image = image
				self.imageView.hidden = false
			} else {
				self.imageView?.hidden = true
			}
			
//			if let image = self.image {
//				CATransaction.setDisableActions(true)
//				if self.imageLayer == nil {
//					self.imageLayer = CALayer()
//					self.layer.addSublayer(self.imageLayer)
//					self.imageLayer.backgroundColor = UIColor.orangeColor().CGColor
//				}
//				
//				self.imageLayer.hidden = false
//				self.imageLayer.contents = image.CGImage
//				self.imageLayer.frame = self.frameForImageSize(image.size)
//				println("setting layer frame to \(self.imageLayer.frame)")
//				CATransaction.setDisableActions(false)
//			} else {
//				self.imageLayer?.hidden = true
//			}
		}
	
	}

	func frameForImageSize(size: CGSize) -> CGRect {
		var aspectRatio = size.width / size.height
		var myRatio = self.bounds.width / self.bounds.height
		var height: CGFloat = 0
		var width: CGFloat = 0

		switch self.contentMode {
			case .ScaleAspectFit: fallthrough
			default:
				if aspectRatio == myRatio {
					return self.bounds
				} else if aspectRatio < myRatio {
					height = self.bounds.height
					width = height * aspectRatio
					return CGRect(x: (self.bounds.width - width) / 2, y: (self.bounds.height - height) / 2, width: width, height: height)
				} else {
					width = self.bounds.width
					height = width / aspectRatio
					return CGRect(x: (self.bounds.width - width) / 2, y: (self.bounds.height - height) / 2, width: width, height: height)
				}
		}
	}
	public override func didMoveToSuperview() {
		super.didMoveToSuperview()
		
		if Hoard.debugging && self.urlLabel == nil {
			self.urlLabel = UILabel(frame: CGRect(x: 0.0, y: self.bounds.height - 15, width: self.bounds.width, height: 15.0))
			self.addSubview(self.urlLabel!)
			self.urlLabel?.autoresizingMask = .FlexibleWidth | .FlexibleTopMargin
			self.urlLabel?.backgroundColor = UIColor(white: 0.9, alpha: 0.8)
		}
	}
	
	public override func drawRect(rect: CGRect) {
		UIBezierPath(ovalInRect: self.bounds).stroke()
	}

	//=============================================================================================
	//MARK: Full screen
	
	func updateDeviceOrientationNotifications() {
		if self.useDeviceOrientation {
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "orientationChanged:", name: UIDeviceOrientationDidChangeNotification, object: nil)
		} else {
			NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
		}
	}
	
	var fullScreenView: HoardImageGalleryView?
	
	var parentGallery: HoardImageGalleryView?
	var galleryIndex: Int? {
		return self.parentGallery?.imageURLs.indexOf(self.URL!)
	}
	
	func makeFullScreen() {
		var windows = UIApplication.sharedApplication().windows as! [UIWindow]
		
		if let parent = windows[0].rootViewController {
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
		if let host = self.fullScreenView?.superview {
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
