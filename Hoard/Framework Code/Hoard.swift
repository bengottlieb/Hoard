//
//  Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 2/9/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

@objc public protocol HoardImageSource {
	func generateImageForURL(url: NSURL) -> UIImage?
}

public class Hoard: NSObject {
	public class var cache: Hoard { struct s { static let manager = Hoard() }; return s.manager }
	
	override init() {
		super.init()
	}
	
	class func main_thread(block: () -> Void) {
		if NSThread.isMainThread() {
			block()
		} else {
			dispatch_async(dispatch_get_main_queue(), block)
		}
	}
	
	public var maxConcurrentDownloads = 400
	public var active = Set<PendingImage>()
	public var pending = Array<PendingImage>()
	public static var debugging = false
	public weak var source: HoardImageSource?
	
	func requestImageURL(url: NSURL, source: HoardImageSource? = nil, completion: ImageCompletion? = nil) -> PendingImage {
		let pending = PendingImage(url: url, completion: completion)
		
		if pending.isCachedAvailable {
			pending.complete(true)
		} else if let source = source {
			if let image = source.generateImageForURL(url) {
				pending.fetchedImage = image
				HoardDiskCache.cacheForKey(Hoard.mainImageCacheKey).storeImage(image, from: url)
			}
			pending.isComplete = true
			Hoard.main_thread {
				completion?(image: pending.fetchedImage, error: nil, fromCache: false)
			}
		} else {
			self.queue.addOperationWithBlock {
				if let existing = self.findExistingConnectionWithURL(url) {
					existing.dupes.append(pending)
				} else {
					self.enqueue(pending)
				}
			}
		}
		
		return pending
	}
	
	public static let mainImageCacheKey = "main-hoard-cache"
	
	public func clearCache() {
		HoardDiskCache.cacheForKey(Hoard.mainImageCacheKey).clearCache()
	}
	

	//=============================================================================================
	//MARK: Private
	
	func enqueue(pending: PendingImage? = nil) {
		if let pending = pending { self.pending.append(pending) }
		if self.active.count < self.maxConcurrentDownloads && self.pending.count > 0 {
			let next = self.pending[0]
			self.active.insert(next)
			self.pending.removeAtIndex(0)
			next.start()
		}
	}
	
	func findExistingConnectionWithURL(url: NSURL) -> PendingImage? {
		var found = self.pending.filter({ $0.URL == url })
		if found.count > 0 { return found[0] }
		
		found = Array(self.active).filter({ $0.URL == url })
		if found.count > 0 { return found[0] }
		
		return nil
	}
	
	func completedPending(image: PendingImage) {
		self.pending.remove(image)
		
		if image.isComplete {
			self.active.remove(image)
		}
		self.queue.addOperationWithBlock {
			self.enqueue()
		}
	}
	
	func cancelPending(image: PendingImage) {
		self.completedPending(image)
	}
	
	let queue: NSOperationQueue = { var queue = NSOperationQueue(); queue.maxConcurrentOperationCount = 1; return queue }()

}