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
	func isFastImageGeneratorForURL(url: NSURL) -> Bool
}

public class Hoard: NSObject {
	public static var instance = Hoard()
	
	override init() {
		serializerQueue = NSOperationQueue();
		serializerQueue.maxConcurrentOperationCount = 1;
		serializerQueue.qualityOfService = .UserInitiated
		
		maintenanceQueue = NSOperationQueue();
		maintenanceQueue.maxConcurrentOperationCount = 1;
		maintenanceQueue.qualityOfService = .Background
		
		generationQueue = NSOperationQueue();
		generationQueue.qualityOfService = .UserInteractive
		
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
	
	func requestImageURL(url: NSURL, source: HoardImageSource? = nil, cache: HoardCache? = nil, completion: ImageCompletion? = nil) -> PendingImage {
		let pending = PendingImage(url: url, completion: completion)
		
		if pending.isCachedAvailable {
			pending.complete(true)
			return pending
		}
		
		let searchCache = cache ?? Hoard.defaultImageCache
		if let image = searchCache.fetchImage(url) {
			pending.fetchedImage = image
			pending.isComplete = true
			Hoard.main_thread {
				completion?(image: pending.fetchedImage, error: nil, fromCache: false)
			}
		}
		
		if let source = source {
			let generationBlock = {
				if let image = source.generateImageForURL(url) {
					pending.fetchedImage = image
					Hoard.defaultImageCache.storeImage(image, from: url)
				}
				pending.isComplete = true
				Hoard.main_thread {
					completion?(image: pending.fetchedImage, error: nil, fromCache: false)
				}
			}
			if source.isFastImageGeneratorForURL(url) {
				generationBlock()
			} else {
				self.generationQueue.addOperationWithBlock(generationBlock)
			}
		} else {
			self.serializerQueue.addOperationWithBlock {
				if let existing = self.findExistingConnectionWithURL(url) {
					existing.dupes.append(pending)
				} else {
					self.enqueue(pending)
				}
			}
		}
		
		return pending
	}
	
	public static var defaultImageCache = HoardCache.cacheForKey(Hoard.mainImageCacheKey)
	public static let mainImageCacheKey = "main-hoard-cache"
	
	//=============================================================================================
	//MARK: Private
	
	class func addMaintenanceBlock(block: () -> Void) {
		Hoard.instance.maintenanceQueue.addOperationWithBlock(block)
	}
	
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
		self.serializerQueue.addOperationWithBlock {
			self.enqueue()
		}
	}
	
	func cancelPending(image: PendingImage) {
		self.completedPending(image)
	}
	
	let serializerQueue: NSOperationQueue
	let maintenanceQueue: NSOperationQueue
	let generationQueue: NSOperationQueue

}