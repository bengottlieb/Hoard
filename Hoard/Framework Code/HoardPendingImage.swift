//
//  PendingImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import Plug

public typealias ImageCompletion = (_ image: HoardPrimitiveImage?, _ error: NSError?, _ fromCache: Bool) -> Void

open class PendingImage: NSObject {
	open class var defaultPriority: Int { return 10 }
	
	open let URL: Foundation.URL
	open let completion: ImageCompletion?
	open let priority: Int
	open var error: NSError?
	
	open class func request(_ url: Foundation.URL, source: HoardImageSource? = nil, cache: Cache? = nil, completion: ImageCompletion? = nil) -> PendingImage {
		let pending = PendingImage(url: url, cache: cache, completion: completion)
		
		if pending.isCachedAvailable {
			pending.complete(true)
			return pending
		}
		
		let searchCache = pending.cache
		if let image = searchCache.fetchImage(url) {
			pending.fetchedImage = image
			pending.complete(true)
//				pending.isComplete = true
//				HoardState.main_thread {
//					completion?(image: pending.fetchedImage, error: nil, fromCache: false)
//				}
			return pending
		}
		
		if let source = source {
			let generationBlock = {
				if let image = source.generateImage(for: url) {
					pending.fetchedImage = image
					searchCache.store(image, from: url)
				}
				pending.isComplete = true
				HoardState.main_thread {
					completion?(pending.fetchedImage, nil, false)
				}
			}
			if source.isFastImageGenerator(for: url) {
				generationBlock()
			} else {
				HoardState.instance.generationQueue.addOperation(generationBlock)
			}
		} else {
			HoardState.instance.serializerQueue.addOperation {
				if let existing = HoardState.instance.findExistingConnectionWithURL(url) {
					existing.dupes.append(pending)
				} else {
					HoardState.instance.enqueue(pending)
				}
			}
		}
		
		return pending
	}
	

	public init(url: Foundation.URL, cache imageCache: Cache? = nil, priority pri: Int = PendingImage.defaultPriority, completion comp: ImageCompletion?) {
		URL = url
		completion = comp
		priority = pri
		cache = imageCache ?? HoardState.defaultImageCache
		
		super.init()
	}
	
	var dupes: [PendingImage] = []
	
	func start() {
		Plug.request(method: .GET, url: self.URL, channel: Plug.Channel.resourceChannel).completion { conn, data in
			if let image = HoardPrimitiveImage(data: data.data) {
				self.fetchedImage = image
			}
			self.complete(false)
			self.cache.store(NSData(data: data.data), from: self.URL)
		}.error { conn, error in
			print("error downloading from \(self.URL): \(error)")
			if HoardState.debugLevel == .high { conn.log() }
			self.error = error
			self.complete(false)
		}.start()
	}
	
	open func cancel() {
		HoardState.instance.cancelPending(self)
		self.isCancelled = true
	}
	
	open var isCachedAvailable: Bool {
		if self.fetchedImage != nil { return true }
		
		return self.cache.isCacheDataAvailable(self.URL)
	}
	
	func complete(_ fromCache: Bool, image: HoardPrimitiveImage? = nil) {
		self.isComplete = true
		if !self.isCancelled {
			for dupe in self.dupes {
				dupe.complete(fromCache, image: self.image)
			}
			HoardState.main_thread {
				if let completion = self.completion {
					completion(self.image ?? image, self.error, fromCache)
				}
			}
		}
		
		if image == nil { HoardState.instance.completedPending(self) }
	}
	
	open var image: HoardPrimitiveImage? {
		if let image = self.fetchedImage { return image }
		
		if let image = self.cache.fetchImage(self.URL) {
			self.fetchedImage = image
			return image
		}
		
		return nil
	}
	
	//=============================================================================================
	//MARK: Private
	
	var fetchedImage: HoardPrimitiveImage?
	var localURL: Foundation.URL?
	var isCancelled = false
	var isComplete = false
	let cache: Cache
}
