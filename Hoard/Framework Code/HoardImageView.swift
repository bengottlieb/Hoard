//
//  ImageView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

var s_currentImageView: ImageView?

open class HoardImageView: ImageView {}

open class ImageView: UIView {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	open var imageSource: HoardImageSource?
	open var imageCache: Cache?
	open var useDeviceOrientation = false { didSet { self.updateDeviceOrientationNotifications() }}
	open var tapForFullScreen = false { didSet { self.updateTapForFullScren() }}
	
	var shouldFadeIn = false
	var imageURL: URL?
	open var url: URL? {
		set {
			if newValue == self.displayedURL && (self.image != nil || self.pendingImage != nil)  { return }
			if let pendingURL = self.pendingImage?.url, let actualURL = newValue, actualURL == pendingURL { return }
			self.shouldFadeIn = false
			self.set(url: newValue)
			self.shouldFadeIn = true
			if self.pendingImage?.isComplete ?? false { self.pendingImage = nil }
		}
		get { return self.imageURL }
	}
	
	open func reloadImage() {
		if let url = self.url {
			self.set(url: url)
		}
	}
	
	var loadingIndicator: UIActivityIndicatorView!
	func showActivityIndicator() {
		if self.loadingIndicator == nil {
			self.loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
			self.loadingIndicator.hidesWhenStopped = true
			self.addSubview(self.loadingIndicator)
		}
		self.loadingIndicator.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
		self.loadingIndicator.startAnimating()
	}
	func hideActivityIndicator() {
		self.loadingIndicator?.stopAnimating()
	}
	
	open func set(url: URL?, placeholder: UIImage? = nil, duration: TimeInterval = 0.2) {
		self.imageURL = url
		
		self.pendingImage?.cancel()
		
		if let url = url {
			self.showActivityIndicator()
			
			if HoardState.debugLevel != .none { self.backgroundColor = UIColor(red: CGFloat(url.absoluteString.hash % 255) / 255.0, green: CGFloat(url.absoluteString.hash % 253) / 255.0, blue: CGFloat(url.absoluteString.hash % 254) / 255.0, alpha: 1.0) }
			let tempURL = url
			self.displayedURL = nil
			self.pendingImage = PendingImage.request(from: url, source: self.imageSource, cache: self.imageCache, completion: { [weak self] image, error, fromCache in
				if let imageView = self {
					if let error = error { print("Error while downloading image from \(url): \(error)") }
					imageView.hideActivityIndicator()
					
					if let image = image, let view = self {
						imageView.displayedURL = url

						if imageView.imageURL == tempURL && image != imageView.image {
							//println("received image: \(imageView.URL) at \(imageView.galleryIndex)")
							imageView.image = image
							if imageView.revealAnimationDuration > 0.0 && !fromCache && view.shouldFadeIn {
								let anim = CABasicAnimation(keyPath: "opacity")
								anim.duration = imageView.revealAnimationDuration
								anim.fromValue = 0.0
								anim.toValue = 1.0
								imageView.imageLayer!.add(anim, forKey: "reveal")
							}
							imageView.pendingImage = nil
						}
					} else {
						imageView.displayedURL = nil
						imageView.image = nil
						print("missing image: \(tempURL)")
					}
				}
			})
			
			if let image = self.pendingImage?.image, let url = self.pendingImage?.url , (self.displayedURL == nil || self.displayedURL != url) {
				self.image = image
				self.displayedURL = url
			}
		} else {
			self.hideActivityIndicator()
		}

		
		self.placeholder = placeholder
		if self.image == nil { self.image = placeholder }
		self.revealAnimationDuration = duration * (HoardState.debugLevel != .none ? 10.0 : 1.0)
	}
	
	func prepareForReuse() {
		self.hideActivityIndicator()
		self.displayedURL = nil
		self.imageURL = nil
		self.image = nil
		self.backgroundColor = UIColor.clear
	}
	
	var displayedURL: URL? { didSet {
		if let url = self.displayedURL {
			self.urlLabel?.text = url.absoluteString
		} else {
			self.backgroundColor = UIColor.black
		}
	}}
	var placeholder: UIImage?
	
	var urlLabel: UILabel?
	
	open var revealAnimationDuration = 0.2 * (HoardState.debugLevel != .none ? 10.0 : 1.0)
	open var pendingImage: PendingImage?
	
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
				self.imageLayer.contents = image.cgImage
				self.imageLayer.frame = self.frame(for: image.size)
			} else {
				self.imageLayer?.contents = nil
				self.imageLayer?.opacity = 0.0
			}
			CATransaction.setDisableActions(false)
		}
	
	}

	func frame(for size: CGSize) -> CGRect {
		let aspectRatio = size.width / size.height
		let myRatio = self.bounds.width / self.bounds.height
		var height: CGFloat = 0
		var width: CGFloat = 0

		switch self.contentMode {
			case .scaleAspectFill:
				if aspectRatio == myRatio {			//no need to add margins
					return self.bounds
				} else if aspectRatio < myRatio {	// image is narrower than view
					width = self.bounds.width
					height = width / aspectRatio
				} else {							// view is narrower than image
					height = self.bounds.height
					width = height * aspectRatio
				}
				return CGRect(x: (self.bounds.width - width) / 2, y: (self.bounds.height - height) / 2, width: width, height: height)
			
			case .scaleAspectFit: fallthrough
			
			default:
				if aspectRatio == myRatio {			//no need to add margins
					return self.bounds
				} else if aspectRatio < myRatio {	// image is narrower than view
					height = self.bounds.height
					width = height * aspectRatio
				} else {							// view is narrower than image
					width = self.bounds.width
					height = width / aspectRatio
				}
				return CGRect(x: (self.bounds.width - width) / 2, y: (self.bounds.height - height) / 2, width: width, height: height)
		}
	}
	open override func didMoveToSuperview() {
		super.didMoveToSuperview()
		
		if HoardState.debugLevel != .none && self.urlLabel == nil {
			self.urlLabel = UILabel(frame: CGRect(x: 0.0, y: self.bounds.height - 15, width: self.bounds.width, height: 15.0))
			self.addSubview(self.urlLabel!)
			self.urlLabel?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
			self.urlLabel?.backgroundColor = UIColor(white: 0.9, alpha: 0.1)
			self.urlLabel?.layer.zPosition = 100
		}
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()
		if let image = self.image {
			self.imageLayer?.frame = self.frame(for: image.size)
		}
	}
	
	//=============================================================================================
	//MARK: Full screen
	
	func updateDeviceOrientationNotifications() {
		if self.useDeviceOrientation {
			NotificationCenter.default.addObserver(self, selector: #selector(ImageView.orientationChanged), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
		} else {
			NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
		}
	}
	
	var fullScreenView: ImageGalleryView?
	
	var parentGallery: ImageGalleryView?
	var galleryIndex: Int? {
		return self.parentGallery?.imageURLs.index(of: self.url!)
	}
	
	open func makeFullScreen() -> ImageGalleryView? {
		if let parent = self.window?.rootViewController {
			s_currentImageView = self
			let host = parent.view
			let newFrame = self.convert(self.bounds, to: host)
			self.fullScreenView = ImageGalleryView(frame: newFrame)
			
			if let parent = self.parentGallery {
				self.fullScreenView!.load(urls: parent.imageURLs, placeholder: self.placeholder)
				self.fullScreenView!.setCurrent(index: parent.imageURLs.index(of: self.url!) ?? 0, animated: false)
			} else {
				self.fullScreenView?.load(urls: self.parentGallery?.imageURLs ?? [self.url!], placeholder: self.placeholder)
			}
			self.fullScreenView?.backgroundColor = UIColor.black
			//self.fullScreenView?.image = self.image
			self.fullScreenView?.contentMode = .scaleAspectFit
			self.fullScreenView?.isUserInteractionEnabled = true
			self.fullScreenView?.clipsToBounds = true
			self.fullScreenView?.alpha = 1.0
			self.fullScreenView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			host?.addSubview(self.fullScreenView!)
			host?.bringSubview(toFront: self.fullScreenView!)

			UIView.animate(withDuration: 0.25 * (HoardState.debugLevel != .none ? 1.0 : 1.0), delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
				self.alpha = 0.0
				self.fullScreenView?.alpha = 1.0
				self.fullScreenView?.frame = (host?.frame)!
			}, completion: { completed in })
			self.fullScreenView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ImageView.fullScreenTouched)))
		//	self.fullScreenView?.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: "share:"))
		}
		
		if let countView = self.parentGallery?.countView {
			self.fullScreenView?.addCountView(countView, atLocation: self.parentGallery!.countLocation)
		}
		return self.fullScreenView
	}
	
	@objc func fullScreenTouched(recog: UITapGestureRecognizer) {
		let location = recog.location(in: self.fullScreenView!)
		let hit = self.fullScreenView!.hitTest(location, with: nil)
		
		if hit is ImageView { self.dismissFullScreen() }
	}
	
	func dismissFullScreen() {
		if s_currentImageView == self { s_currentImageView = nil }
		self.parentGallery?.setCurrent(index: self.fullScreenView!.currentIndex, animated: false)
		if let host = self.fullScreenView?.superview {
			let newFrame = self.convert(self.bounds, to: host)
			UIView.animate(withDuration: 0.25 * (HoardState.debugLevel != .none ? 1.0 : 1.0), delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
				self.alpha = 1.0
				self.fullScreenView?.alpha = 0.0
				if self.superview != nil { self.fullScreenView?.frame = newFrame }
				}, completion: { completed in
					self.alpha = 1.0
					self.fullScreenView?.removeFromSuperview()
					self.fullScreenView = nil
					self.parentGallery?.updateImageCount()
			})
		}
	}
	
	@objc func orientationChanged(note: Notification) {
		var frame = UIScreen.main.bounds
		var transform = CGAffineTransform.identity
		
		switch (UIDevice.current.orientation) {
		case .landscapeLeft:
			transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
			frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
			
		case .landscapeRight:
			transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2.0)
			frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
			
		default: break
			
		}
		UIView.animate(withDuration: 0.2 * (HoardState.debugLevel != .none ? 10.0 : 1.0), animations: {
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
				self.isUserInteractionEnabled = true
				self.tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ImageView.imageTapped))
				self.addGestureRecognizer(self.tapRecognizer!)
			}
		} else {
			if let recog = self.tapRecognizer {
				self.removeGestureRecognizer(recog)
				self.tapRecognizer = nil
			}
		}
	}
	
	@objc func imageTapped(recog: UITapGestureRecognizer) {
		let location = recog.location(in: self)
		if let tapped = self.hitTest(location, with: nil) as? ImageView {
			_ = tapped.makeFullScreen()
		}
	}
	


}
