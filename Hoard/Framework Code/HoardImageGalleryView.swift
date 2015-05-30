//
//  HoardImageGalleryView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/27/15.
//  Copyright (c) 2015 Ben Gottlieb. All rights reserved.
//

import UIKit
import Hoard

public class HoardImageGalleryView: UIImageView, UIScrollViewDelegate {
	public func setURLs(urls: [NSURL], placeholder: UIImage? = nil, duration: NSTimeInterval = 0.2) {
		self.animationDuration = duration
		self.placeholderImage = placeholder
		self.imageURLs = urls
	}
	
	public var imageURLs: [NSURL] = [] { didSet { if self.imageURLs != oldValue { self.setNeedsLayout() } }}
	public var useDeviceOrientation = false
	public var tapForFullScreen = false
	public var placeholderImage: UIImage? { didSet { if self.placeholderImage != oldValue { self.setNeedsLayout() } }}
	public var revealAnimationDuration = 0.2 { didSet { if self.revealAnimationDuration != oldValue { self.setNeedsLayout() } }}
	public var showPageIndicators = true { didSet { if self.showPageIndicators != oldValue { self.setupPageIndicators() }}}
	public var pageIndicatorOffset: CGFloat = 0.1
	public var pageIndicators: UIPageControl?
	
	public func setCurrentIndex(index: Int, animated: Bool) {
		self.setupScrollView()
		self.scrollView.setContentOffset(CGPoint(x: self.scrollView.bounds.width * CGFloat(index), y: 0.0), animated: animated)
	}
	
	public var currentIndex: Int {
		if let scrollView = self.scrollView { return Int(scrollView.contentOffset.x / scrollView.bounds.width) }
		return 0
	}
	
	public var currentImageView: HoardImageView? {
		var index = self.currentIndex
		if index < 0 || index >= self.imageURLs.count { return nil }
		
		for imageView in self.usedImageViews {
			if imageView.URL == self.imageURLs[index] { return imageView }
		}
		return nil
	}
	
	public func makeFullScreen() {
		self.currentImageView?.makeFullScreen()
	}
	
	//=============================================================================================
	//MARK: Private
	deinit {
		
	}
	
	public override func didMoveToSuperview() { self.setup() }
	public func setup() { self.setupScrollView(); if self.showPageIndicators { self.setupPageIndicators() } }
	
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
	
	func setupPageIndicators() {
		if self.showPageIndicators {
			if self.pageIndicators == nil {
				self.pageIndicators = UIPageControl(frame: CGRectZero)
				self.pageIndicators?.hidesForSinglePage = true
				self.addSubview(self.pageIndicators!)
				self.pageIndicators?.addTarget(self, action: "pageIndicatorValueChanged:", forControlEvents: .ValueChanged)
				self.pageIndicators?.autoresizingMask = .FlexibleTopMargin | .FlexibleLeftMargin | .FlexibleRightMargin
			}
			
			var size = self.pageIndicators!.sizeForNumberOfPages(self.imageURLs.count)
			self.pageIndicators?.numberOfPages = self.imageURLs.count
			self.pageIndicators?.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
			self.pageIndicators?.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height * (1.0 - self.pageIndicatorOffset))
		} else {
			self.pageIndicators?.hidden = true
		}
	}
	
	func pageIndicatorValueChanged(pageControl: UIPageControl) {
		self.setCurrentIndex(pageControl.currentPage, animated: true)
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
		if self.usedImageViews.count == 0 { self.updateImageViews() }
		self.setupPageIndicators()
	}
	
	
	var availableImageViews = Set<HoardImageView>()
	var usedImageViews: [HoardImageView] = []
	
	func updateImageViews() {
		var firstVisibleIndex = Int(abs(self.scrollView.contentOffset.x) / self.bounds.size.width)
		var removeThese = self.usedImageViews
		
		var numberOfVisible: Int = (CGFloat(firstVisibleIndex) * self.scrollView.bounds.width != self.scrollView.contentOffset.x) ? 2 : 1
		let visibleURLs = Array(self.imageURLs[firstVisibleIndex..<Int(firstVisibleIndex + min(numberOfVisible, self.imageURLs.count - firstVisibleIndex))])
		var instantiatedURLs: [NSURL] = []
		
		for view in self.usedImageViews {
			if let url = view.URL where visibleURLs.contains(url) {
				removeThese.remove(view)
				instantiatedURLs.append(url)
			}
		}
		
		for view in removeThese {
			view.removeFromSuperview()
			view.prepareForReuse()
			self.usedImageViews.remove(view)
			self.availableImageViews.insert(view)
		}
		
		var firstURLIndex = firstVisibleIndex
		var left = self.bounds.width * CGFloat(firstVisibleIndex)
		
		for index in firstURLIndex..<self.imageURLs.count {
			//if !(self.scrollView.tracking || self.scrollView.dragging || self.scrollView.decelerating) && self.usedImageViews.count > 0 { break }
			
			if (left - self.scrollView.contentOffset.x) >= self.bounds.width { break }

			var url = self.imageURLs[index]
			if !instantiatedURLs.contains(url) {
				var view = self.nextAvailableImageView
				view.setURL(self.imageURLs[index], placeholder: self.placeholderImage)
				view.bounds = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
				view.center = CGPoint(x: left + view.bounds.width / 2, y: view.bounds.height / 2)
				self.usedImageViews.append(view)
				self.scrollView.addSubview(view)
			}
			
			left += self.bounds.width
		}
		
		self.scrollView.contentSize = CGSize(width: self.scrollView.bounds.width * CGFloat(self.imageURLs.count), height: self.scrollView.bounds.height)
	}
	
	var nextAvailableImageView: HoardImageView {
		if let view = self.availableImageViews.first {
			self.availableImageViews.remove(view)
			return view
		}
		
		var view = HoardImageView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
		view.clipsToBounds = true
		view.parentGallery = self
		view.userInteractionEnabled = true
		view.contentMode = .ScaleAspectFit
		view.tapForFullScreen = self.tapForFullScreen
		view.useDeviceOrientation = self.useDeviceOrientation
		return view
	}
	
	public func scrollViewDidScroll(scrollView: UIScrollView) { self.updateImageViews() }
	public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	
	
}
