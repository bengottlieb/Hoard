//
//  PendingImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import Plug
import CrossPlatformKit

public typealias ImageCompletion = (_ image: UXImage?, _ error: Error?, _ fromCache: Bool) -> Void

open class PendingImage: NSObject {
	open class var defaultPriority: Int { return 10 }
	
	open let url: URL
	open let completion: ImageCompletion?
	open let priority: Int
	open var error: Error?
	
	open class func request(from url: URL, source: HoardImageSource? = nil, cache: Cache? = nil, completion: ImageCompletion? = nil) -> PendingImage {
		let pending = PendingImage(url: url, cache: cache, completion: completion)
		
		if pending.isCachedAvailable {
			pending.complete(true)
			return pending
		}
		
		let searchCache = pending.cache
		if let image = searchCache.fetchImage(for: url) {
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
					searchCache.store(object: image, from: url)
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
				if let existing = HoardState.instance.findExistingConnection(with: url) {
					existing.dupes.append(pending)
				} else {
					HoardState.instance.enqueue(pending: pending)
				}
			}
		}
		
		return pending
	}
	

	public init(url: URL, cache imageCache: Cache? = nil, priority pri: Int = PendingImage.defaultPriority, completion comp: ImageCompletion?) {
		self.url = url
		self.completion = comp
		self.priority = pri
		self.cache = imageCache ?? HoardState.defaultImageCache
		
		super.init()
	}
	
	var dupes: [PendingImage] = []
	
	func start() {
		Plug.request(method: .GET, url: self.url, channel: Plug.Channel.resourceChannel).completion { conn, data in
			if let image = UXImage(data: data.data) {
				self.fetchedImage = image
			}
			self.complete(false)
			self.cache.store(object: data.data, from: self.url)
		}.error { conn, error in
			print("error downloading from \(self.url): \(error)")
			if HoardState.debugLevel == .high { conn.log() }
			self.error = error
			self.complete(false)
		}.start()
	}
	
	open func cancel() {
		HoardState.instance.cancel(image: self)
		self.isCancelled = true
	}
	
	open var isCachedAvailable: Bool {
		if self.fetchedImage != nil { return true }
		
		return self.cache.isCacheDataAvailable(for: self.url)
	}
	
	func complete(_ fromCache: Bool, image: UXImage? = nil) {
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
		
		if image == nil { HoardState.instance.completed(image: self) }
	}
	
	open var image: UXImage? {
		if let image = self.fetchedImage { return image }
		
		if let image = self.cache.fetchImage(for: self.url) {
			self.fetchedImage = image
			return image
		}
		
		return nil
	}
	
	//=============================================================================================
	//MARK: Private
	
	var fetchedImage: UXImage?
	var localURL: URL?
	var isCancelled = false
	var isComplete = false
	let cache: Cache
}
