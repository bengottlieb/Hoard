//
//  ImageGalleryView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/27/15.
//  Copyright (c) 2015 Ben Gottlieb. All rights reserved.
//

#if os(iOS)
import UIKit

open class ImageGalleryView: UIImageView, UIScrollViewDelegate {
	public enum ImageCountLocation { case none, upperLeft, upperRight, lowerLeft, lowerRight }

	open func load(urls: [URL], placeholder: UIImage? = nil, duration: TimeInterval = 0.2) {
		self.animationDuration = duration
		self.placeholderImage = placeholder
		self.imageURLs = urls
	}
	
	open var imageURLs: [URL] = [] { didSet { if self.imageURLs != oldValue { self.setNeedsLayout() } }}
	open var useDeviceOrientation = false
	open var tapForFullScreen = false
	open var placeholderImage: UIImage? { didSet { if self.placeholderImage != oldValue { self.setNeedsLayout() } }}
	open var revealAnimationDuration = 0.2 { didSet { if self.revealAnimationDuration != oldValue { self.setNeedsLayout() } }}
	open var showPageIndicators = true { didSet { if self.showPageIndicators != oldValue { self.setupPageIndicators() }}}
	open var pageIndicatorOffset: CGFloat = 0.1
	open var pageIndicators: UIPageControl?
	open var countLocation: ImageCountLocation = .none { didSet { self.updateImageCount() }}
	open var countView: ImageCountView?
	open func addCountView(_ view: ImageCountView = ImageCountView.defaultCountView(), atLocation location: ImageCountLocation = .upperRight) {
		self.countView?.removeFromSuperview()
		self.countView = view
		self.addSubview(view)
		self.countLocation = location
		self.updateImageCount()
	}
	
	
	open func setCurrent(index: Int, animated: Bool) {
		self.setupScrollView()
		self.scrollView.setContentOffset(CGPoint(x: self.scrollView.bounds.width * CGFloat(index), y: 0.0), animated: animated)
		self.updateImageCount()
	}
	
	open var currentIndex: Int {
		if let scrollView = self.scrollView { return Int(scrollView.contentOffset.x / scrollView.bounds.width) }
		return 0
	}
	
	open var currentImageView: ImageView? {
		let index = self.currentIndex
		if index < 0 || index >= self.imageURLs.count { return nil }
		
		for imageView in self.usedImageViews {
			if imageView.url == self.imageURLs[index] { return imageView }
		}
		return nil
	}
	
	open func makeFullScreen() {
		_ = self.currentImageView?.makeFullScreen()
	}
	
	//=============================================================================================
	//MARK: Private
	deinit {
		
	}
	
	open override func didMoveToSuperview() { self.setup() }
	open func setup() {
		self.contentMode = .scaleAspectFit
		self.setupScrollView();
		if self.showPageIndicators { self.setupPageIndicators() }
	}
	
	//=============================================================================================
	//MARK: Layout
	var scrollView: UIScrollView!
	
	func setupScrollView() {
		if self.scrollView == nil {
			self.scrollView = UIScrollView(frame: self.bounds)
			self.scrollView.delegate = self
			self.addSubview(self.scrollView)
			self.scrollView.isPagingEnabled = true
			self.scrollView.isDirectionalLockEnabled = true
			self.scrollView.backgroundColor = UIColor.black
			self.scrollView.showsHorizontalScrollIndicator = false
			self.scrollView.showsVerticalScrollIndicator = false
			self.isUserInteractionEnabled = true
		}
	}
	
	func setupPageIndicators() {
		if self.showPageIndicators {
			if self.pageIndicators == nil {
				self.pageIndicators = UIPageControl(frame: CGRect.zero)
				self.pageIndicators?.hidesForSinglePage = true
				self.addSubview(self.pageIndicators!)
				self.pageIndicators?.backgroundColor = UIColor.clear
				self.pageIndicators?.addTarget(self, action: #selector(ImageGalleryView.pageIndicatorValueChanged), for: .valueChanged)
				self.pageIndicators?.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
			}
			
			let size = self.pageIndicators!.size(forNumberOfPages: self.imageURLs.count)
			self.pageIndicators?.numberOfPages = self.imageURLs.count
			self.pageIndicators?.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
			self.pageIndicators?.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height * (1.0 - self.pageIndicatorOffset))
		} else {
			self.pageIndicators?.isHidden = true
		}
	}
	
	@objc func pageIndicatorValueChanged(_ pageControl: UIPageControl) {
		self.setCurrent(index: pageControl.currentPage, animated: true)
	}
	
	func resetContents() {
		for view in self.usedImageViews {
			view.removeFromSuperview()
			self.availableImageViews.insert(view)
		}
		self.usedImageViews = []
		let index = self.scrollView.contentOffset.x / self.scrollView.bounds.width
		self.scrollView.frame = self.bounds
		self.scrollView.contentOffset = CGPoint(x: CGFloat(index) * self.scrollView.bounds.width, y: 0)
		self.updateImageViews()
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()
		
		self.setupScrollView()
		if self.scrollView.frame != self.bounds { self.resetContents() }
		if self.usedImageViews.count == 0 { self.updateImageViews() }
		self.setupPageIndicators()
	}
	
	
	var availableImageViews = Set<ImageView>()
	var usedImageViews: [ImageView] = []
	
	func updateImageViews() {
		let firstVisibleIndex = Int(abs(self.scrollView.contentOffset.x) / self.bounds.size.width)
		var removeThese = self.usedImageViews
		
		let numberOfVisible: Int = (CGFloat(firstVisibleIndex) * self.scrollView.bounds.width != self.scrollView.contentOffset.x) ? 2 : 1
		let visibleURLs = Array(self.imageURLs[firstVisibleIndex..<Int(firstVisibleIndex + min(numberOfVisible, self.imageURLs.count - firstVisibleIndex))])
		var instantiatedURLs: [URL] = []
		
		for view in self.usedImageViews {
			if let url = view.url , visibleURLs.contains(url) {
				if let index = removeThese.firstIndex(of: view) { removeThese.remove(at: index) }
				instantiatedURLs.append(url)
			}
		}
		
		for view in removeThese {
			view.removeFromSuperview()
			view.prepareForReuse()
			if let index = usedImageViews.firstIndex(of: view) { usedImageViews.remove(at: index) }
			self.availableImageViews.insert(view)
		}
		
		let firstURLIndex = firstVisibleIndex
		var left = self.bounds.width * CGFloat(firstVisibleIndex)
		
		for index in firstURLIndex..<self.imageURLs.count {
			//if !(self.scrollView.tracking || self.scrollView.dragging || self.scrollView.decelerating) && self.usedImageViews.count > 0 { break }
			
			if (left - self.scrollView.contentOffset.x) >= self.bounds.width { break }

			let url = self.imageURLs[index]
			if !instantiatedURLs.contains(url) {
				let view = self.nextAvailableImageView
				view.set(url: self.imageURLs[index], placeholder: self.placeholderImage)
				view.bounds = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
				view.center = CGPoint(x: left + view.bounds.width / 2, y: view.bounds.height / 2)
				self.usedImageViews.append(view)
				self.scrollView.addSubview(view)
			}
			
			left += self.bounds.width
		}
		
		self.scrollView.contentSize = CGSize(width: self.scrollView.bounds.width * CGFloat(self.imageURLs.count), height: self.scrollView.bounds.height)
		self.updateImageCount()
	}
	
	var nextAvailableImageView: ImageView {
		if let view = self.availableImageViews.first {
			self.availableImageViews.remove(view)
			return view
		}
		
		let view = ImageView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
		view.clipsToBounds = true
		view.parentGallery = self
		view.isUserInteractionEnabled = true
		view.contentMode = self.contentMode
		view.tapForFullScreen = self.tapForFullScreen
		view.useDeviceOrientation = self.useDeviceOrientation
		return view
	}
	
	open func scrollViewDidScroll(_ scrollView: UIScrollView) { self.updateImageViews() }
	open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		self.pageIndicators?.currentPage = self.currentIndex
	}
	
	open func updateImageCount() {
		if let view = self.countView {
			let bounds = self.bounds
			var center = CGPoint.zero
			let hOffset: CGFloat = 60, vOffset: CGFloat = 30
			
			switch self.countLocation {
			case .upperLeft: center = CGPoint(x: hOffset, y: vOffset)
			case .upperRight: center = CGPoint(x: bounds.width - hOffset, y: vOffset)
			case .lowerLeft: center = CGPoint(x: hOffset, y: bounds.height - vOffset)
			case .lowerRight: center = CGPoint(x: bounds.width - hOffset, y: bounds.height - vOffset)
			default: return
			}
			
			self.addSubview(view)
			view.center = center
			view.currentImageIndex = self.currentIndex
			view.numberOfImages = self.imageURLs.count
		}
	}
}
#endif
