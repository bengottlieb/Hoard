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

public class PendingImage: NSObject {
	public class var defaultPriority: Int { return 10 }
	
	public let URL: NSURL
	public let completion: ImageCompletion?
	public let priority: Int
	public var error: NSError?
	
	public init(url: NSURL, completion comp: ImageCompletion?, priority pri: Int = PendingImage.defaultPriority) {
		URL = url
		completion = comp
		priority = pri
		
		super.init()
	}
	
	var dupes: [PendingImage] = []
	
	func start() {
		Plug.request(.GET, URL: self.URL, channel: Plug.Channel.resourceChannel).completion({ conn, data in
			if let image = UIImage(data: data) {
				self.fetchedImage = image
			}
			self.complete(false)
			Hoard.defaultImageCache.store(data, from: self.URL)
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
		
		return Hoard.defaultImageCache.isCacheDataAvailable(self.URL)
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
		
		if let image = Hoard.defaultImageCache.fetchImage(self.URL) {
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
}