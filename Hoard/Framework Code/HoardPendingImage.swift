//
//  PendingImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import Plug

public typealias ImageCompletion = (image: UIImage?, error: NSError?, fromCache: Bool) -> Void

extension Hoard {
	public class PendingImage: NSObject {
		public class var defaultPriority: Int { return 10 }
		
		public let URL: NSURL
		public let completion: ImageCompletion?
		public let priority: Int
		public var error: NSError?
		
		public class func request(url: NSURL, source: HoardImageSource? = nil, cache: Cache? = nil, completion: ImageCompletion? = nil) -> PendingImage {
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
//				Hoard.main_thread {
//					completion?(image: pending.fetchedImage, error: nil, fromCache: false)
//				}
				return pending
			}
			
			if let source = source {
				let generationBlock = {
					if let image = source.generateImageForURL(url) {
						pending.fetchedImage = image
						searchCache.store(image, from: url)
					}
					pending.isComplete = true
					Hoard.main_thread {
						completion?(image: pending.fetchedImage, error: nil, fromCache: false)
					}
				}
				if source.isFastImageGeneratorForURL(url) {
					generationBlock()
				} else {
					Hoard.instance.generationQueue.addOperationWithBlock(generationBlock)
				}
			} else {
				Hoard.instance.serializerQueue.addOperationWithBlock {
					if let existing = Hoard.instance.findExistingConnectionWithURL(url) {
						existing.dupes.append(pending)
					} else {
						Hoard.instance.enqueue(pending)
					}
				}
			}
			
			return pending
		}
		

		public init(url: NSURL, cache imageCache: Cache? = nil, priority pri: Int = PendingImage.defaultPriority, completion comp: ImageCompletion?) {
			URL = url
			completion = comp
			priority = pri
			cache = imageCache ?? Hoard.defaultImageCache
			
			super.init()
		}
		
		var dupes: [PendingImage] = []
		
		func start() {
			Plug.request(.GET, URL: self.URL, channel: Plug.Channel.resourceChannel).completion({ conn, data in
				if let image = UIImage(data: data.data) {
					self.fetchedImage = image
				}
				self.complete(false)
				self.cache.store(data.data, from: self.URL)
			}).error({ conn, error in
				print("error downloading from \(self.URL): \(error)")
				if Hoard.debugLevel == .High { conn.log() }
				self.error = error
				self.complete(false)
			}).start()
		}
		
		public func cancel() {
			Hoard.instance.cancelPending(self)
			self.isCancelled = true
		}
		
		var isCachedAvailable: Bool {
			if self.fetchedImage != nil { return true }
			
			return self.cache.isCacheDataAvailable(self.URL)
		}
		
		func complete(fromCache: Bool, image: UIImage? = nil) {
			self.isComplete = true
			if !self.isCancelled {
				for dupe in self.dupes {
					dupe.complete(fromCache, image: self.image)
				}
				Hoard.main_thread {
					if let completion = self.completion {
						completion(image: self.image ?? image, error: self.error, fromCache: fromCache)
					}
				}
			}
			
			if image == nil { Hoard.instance.completedPending(self) }
		}
		
		public var image: UIImage? {
			if let image = self.fetchedImage { return image }
			
			if let image = self.cache.fetchImage(self.URL) {
				self.fetchedImage = image
				return image
			}
			
			return nil
		}
		
		//=============================================================================================
		//MARK: Private
		
		var fetchedImage: UIImage?
		var localURL: NSURL?
		var isCancelled = false
		var isComplete = false
		let cache: Cache
	}
}