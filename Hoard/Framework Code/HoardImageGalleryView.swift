//
//  HoardImageGalleryView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/27/15.
//  Copyright (c) 2015 Ben Gottlieb. All rights reserved.
//

import UIKit
import Hoard

var s_currentImageView: HoardImageGalleryView?

public class HoardImageGalleryView: UIImageView, UIScrollViewDelegate {
	public func setURLs(urls: [NSURL], placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.animationDuration = duration
		self.placeholderImage = placeholder
		self.imageURLs = urls
	}
	
	public var imageURLs: [NSURL] = [] { didSet { if self.imageURLs != oldValue { self.setNeedsLayout() } }}
	public var useDeviceOrientation = false { didSet { self.updateDeviceOrientationNotifications() }}
	public var tapForFullScreen = false { didSet { self.updateTapForFullScren() }}
	public var placeholderImage: UIImage? { didSet { if self.placeholderImage != oldValue { self.setNeedsLayout() } }}
	public var revealAnimationDuration = 0.2 { didSet { if self.revealAnimationDuration != oldValue { self.setNeedsLayout() } }}
	
	
	//=============================================================================================
	//MARK: Private
	deinit {
		self.removeAsObserver()
	}
	
	var tapRecognizer: UITapGestureRecognizer?
	func updateTapForFullScren() {
		if self.tapForFullScreen {
			if self.tapRecognizer == nil {
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
		if let tapped = self.hitTest(location, withEvent: nil) as? UIImageView {
			if let image = tapped.image { self.makeFullScreen(image) }
		}
	}
	
	public override func didMoveToSuperview() { self.setupScrollView() }
	
	//=============================================================================================
	//MARK: Layout
	var scrollView: UIScrollView!
	
	func setupScrollView() {
		if self.scrollView == nil {
			self.scrollView = UIScrollView(frame: self.bounds)
			self.scrollView.delegate = self
			self.addSubview(self.scrollView)
			self.scrollView.pagingEnabled = true
			self.scrollView.directionalLockEnabled = true
			self.scrollView.backgroundColor = UIColor.blackColor()
			self.scrollView.showsHorizontalScrollIndicator = false
			self.scrollView.showsVerticalScrollIndicator = false
			self.userInteractionEnabled = true
		}
	}
	
	func resetContents() {
		for view in self.usedImageViews {
			view.removeFromSuperview()
			self.availableImageViews.insert(view)
		}
		self.usedImageViews = []
		var index = self.scrollView.contentOffset.x / self.scrollView.bounds.width
		self.scrollView.frame = self.bounds
		self.scrollView.contentOffset = CGPoint(x: CGFloat(index) * self.scrollView.bounds.width, y: 0)
		self.updateImageViews()
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		
		self.setupScrollView()
		if self.scrollView.frame != self.bounds { self.resetContents() }
	}
	
	
	var availableImageViews = Set<HoardImageView>()
	var usedImageViews: [HoardImageView] = []
	
	func updateImageViews() {
		var firstVisibleIndex = Int(abs(self.scrollView.contentOffset.x) / self.bounds.size.width)
		var removeThese = self.usedImageViews
		
		for viewIndex in 0..<self.usedImageViews.count {
			var urlIndex = firstVisibleIndex + viewIndex
			
			if urlIndex >= self.imageURLs.count || viewIndex >= self.usedImageViews.count { break }
			var url = self.imageURLs[urlIndex]
			var view = self.usedImageViews[viewIndex]
			if view.URL! != url || view.frame.rectByIntersecting(self.scrollView.bounds).width == 0 { break }
			removeThese.remove(view)
		}
		
		for view in removeThese {
			view.removeFromSuperview()
			self.usedImageViews.remove(view)
			self.availableImageViews.insert(view)
		}
		
		var firstURLIndex = firstVisibleIndex + self.usedImageViews.count
		var left = self.bounds.width * CGFloat(firstVisibleIndex + self.usedImageViews.count)
		
		for index in firstURLIndex..<self.imageURLs.count {
			if !(self.scrollView.tracking || self.scrollView.dragging || self.scrollView.decelerating) && self.usedImageViews.count > 0 { break }
			var view = self.nextAvailableImageView
			view.setURL(self.imageURLs[index], placeholder: self.placeholderImage, duration: self.revealAnimationDuration)
			view.bounds = self.scrollView.bounds
			view.center = CGPoint(x: left + view.bounds.width / 2, y: view.bounds.height / 2)
			self.usedImageViews.append(view)
			self.scrollView.addSubview(view)
			left += view.bounds.width
			if (left - self.scrollView.contentOffset.x) >= self.bounds.width { break }
			
		}
		self.scrollView.contentSize = CGSize(width: self.scrollView.bounds.width * CGFloat(self.imageURLs.count), height: self.scrollView.bounds.height)
	}
	
	var nextAvailableImageView: HoardImageView {
		if let view = self.availableImageViews.first {
			self.availableImageViews.remove(view)
			return view
		}
		
		var view = HoardImageView(frame: self.bounds)
		view.clipsToBounds = true
		view.userInteractionEnabled = true
		view.contentMode = .ScaleAspectFill
		return view
	}
	
	public func scrollViewDidScroll(scrollView: UIScrollView) { self.updateImageViews() }
	
	
	//=============================================================================================
	//MARK: Full screen
	
	func updateDeviceOrientationNotifications() {
		if self.useDeviceOrientation {
			self.addAsObserver(UIDeviceOrientationDidChangeNotification, selector: "orientationChanged:", object: nil)
		} else {
			NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
		}
	}
	
	var fullScreenView: UIImageView?
	
	func makeFullScreen(image: UIImage) {
		if let parent = UIWindow.rootWindow()?.rootViewController {
			
			s_currentImageView = self
			var host = parent.view
			var newFrame = self.convertRect(self.bounds, toView: host)
			self.fullScreenView = UIImageView(frame: newFrame)
			self.fullScreenView?.backgroundColor = UIColor.blackColor()
			self.fullScreenView?.image = image
			self.fullScreenView?.contentMode = .ScaleAspectFit
			self.fullScreenView?.userInteractionEnabled = true
			self.fullScreenView?.clipsToBounds = true
			self.fullScreenView?.alpha = 0.0
			self.fullScreenView?.autoresizingMask = .FlexibleWidth | .FlexibleHeight
			host.addSubview(self.fullScreenView!)
			UIView.animateWithDuration(0.25, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
				self.alpha = 0.0
				self.fullScreenView?.alpha = 1.0
				self.fullScreenView?.frame = host.frame
				return
				}, completion: { completed in })
			self.fullScreenView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "dismissFullScreen:"))
			self.fullScreenView?.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: "share:"))
		}
	}
	
	func dismissFullScreen(recog: UITapGestureRecognizer) {
		if s_currentImageView == self { s_currentImageView = nil }
		if let parent = UIViewController.frontmostController() {
			var host = parent.view
			var newFrame = self.convertRect(self.bounds, toView: host)
			UIView.animateWithDuration(0.25, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
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
		UIView.animateWithDuration(0.2, animations: {
			self.fullScreenView?.bounds = frame
			self.fullScreenView?.transform = transform
		})
	}
	
	
}
