//
//  HoardImageView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

var s_currentImageView: HoardImageView?


public class HoardImageView: UIView {
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	public var useDeviceOrientation = false { didSet { self.updateDeviceOrientationNotifications() }}
	public var tapForFullScreen = false { didSet { self.updateTapForFullScren() }}
	
	var imageURL: NSURL?
	public var URL: NSURL? {
		set {
			if newValue == self.displayedURL && (self.image != nil || self.pendingImage != nil)  { return }
			if let pendingURL = self.pendingImage?.URL, actualURL = self.URL where actualURL == pendingURL { return }
			self.setURL(newValue)
		}
		get { return self.imageURL }
	}
	
	var loadingIndicator: UIActivityIndicatorView!
	func showActivityIndicator() {
		if self.loadingIndicator == nil {
			self.loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
			self.loadingIndicator.hidesWhenStopped = true
			self.addSubview(self.loadingIndicator)
		}
		self.loadingIndicator.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
		self.loadingIndicator.startAnimating()
	}
	func hideActivityIndicator() {
		self.loadingIndicator?.stopAnimating()
	}
	
	public func setURL(url: NSURL?, placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.imageURL = url
		
		self.pendingImage?.cancel()
		self.showActivityIndicator()
		
		if let url = url {
			if Hoard.debugging { self.backgroundColor = UIColor(red: CGFloat(url.absoluteString!.hash % 255) / 255.0, green: CGFloat(url.absoluteString!.hash % 253) / 255.0, blue: CGFloat(url.absoluteString!.hash % 254) / 255.0, alpha: 1.0) }
			var tempURL = url
			self.displayedURL = nil
			self.pendingImage = Hoard.cache.requestImageURL(url, completion: { [unowned self] image, error, fromCache in
				if let error = error { println("Error while downloading image from \(url): \(error)") }
				self.hideActivityIndicator()
				var gallery = self.parentGallery
				var view = self
				
				if let image = image {
					self.displayedURL = url

					if self.imageURL == tempURL && image != self.image {
						//println("received image: \(self.URL) at \(self.galleryIndex)")
						self.image = image
						if self.revealAnimationDuration > 0.0 && !fromCache {
							var anim = CABasicAnimation(keyPath: "opacity")
							anim.duration = self.revealAnimationDuration
							anim.fromValue = 0.0
							anim.toValue = 1.0
							self.imageLayer!.addAnimation(anim, forKey: "reveal")
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
		self.hideActivityIndicator()
		self.displayedURL = nil
		self.imageURL = nil
		self.image = nil
		self.backgroundColor = UIColor.clearColor()
	}
	
	var displayedURL: NSURL? { didSet {
		if let url = self.displayedURL {
			self.urlLabel?.text = url.absoluteString
		} else {
			self.backgroundColor = UIColor.blackColor()
		}
	}}
	var placeholder: UIImage?
	
	var urlLabel: UILabel?
	
	public var revealAnimationDuration = 0.2 * (Hoard.debugging ? 10.0 : 1.0)
	public var pendingImage: PendingImage?
	
	var tempImageView: UIImageView?
	
	var imageLayer: CALayer!
	var imageView: UIImageView!
	var image: UIImage? {
		didSet {
			CATransaction.setDisableActions(true)
			if let image = self.image {
				if self.imageLayer == nil {
					self.imageLayer = CALayer()
					self.layer.addSublayer(self.imageLayer)
				}
				
				self.imageLayer.opacity = 1.0
				self.imageLayer.contents = image.CGImage
				self.imageLayer.frame = self.frameForImageSize(image.size)
			} else {
				self.imageLayer?.contents = nil
				self.imageLayer?.opacity = 0.0
			}
			CATransaction.setDisableActions(false)
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
			self.urlLabel?.backgroundColor = UIColor(white: 0.9, alpha: 0.1)
			self.urlLabel?.layer.zPosition = 100
		}
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		if let image = self.image {
			self.imageLayer?.frame = self.frameForImageSize(image.size)
		}
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
	
	public func makeFullScreen() -> HoardImageGalleryView? {
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
			self.fullScreenView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "fullScreenTouched:"))
		//	self.fullScreenView?.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: "share:"))
		}
		
		if let countView = self.parentGallery?.countView {
			self.fullScreenView?.addCountView(view: countView, atLocation: self.parentGallery!.countLocation)
		}
		return self.fullScreenView
	}
	
	func fullScreenTouched(recog: UITapGestureRecognizer) {
		var location = recog.locationInView(self.fullScreenView!)
		var hit = self.fullScreenView!.hitTest(location, withEvent: nil)
		
		if let hit = hit as? HoardImageView { self.dismissFullScreen() }
	}
	
	func dismissFullScreen() {
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
					self.parentGallery?.updateImageCount()
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
