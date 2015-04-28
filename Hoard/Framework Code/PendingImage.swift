//
//  PendingImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 4/20/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import Plug

public typealias ImageCompletion = (UIImage?, NSError?) -> Void

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
		Plug.request(method: .GET, URL: self.URL, channel: Plug.Channel.resourceChannel).completion(completion: { data in
			if let image = UIImage(data: data) {
				self.fetchedImage = image
			}
			self.complete()
			
			data.writeToURL(self.imageLocalURL, atomically: true)
		}).error(completion: { error in
			self.error = error
			self.complete()
		}).start()
	}
	
	public func cancel() {
		Hoard.cache.cancelPending(self)
		self.isCancelled = true
	}
	
	var isCachedAvailable: Bool { return self.image != nil }
	
	func complete(image: UIImage? = nil) {
		self.isComplete = true
		if !self.isCancelled {
			for dupe in self.dupes {
				dupe.complete(image: self.image)
			}
			dispatch_async(dispatch_get_main_queue()) {
				self.completion?(self.image ?? image, self.error)
			}
		}
		
		if image == nil { Hoard.cache.completedPending(self) }
	}
	
	public var image: UIImage? {
		if let image = self.fetchedImage { return image }
		
		var url = self.imageLocalURL
		
		if NSFileManager.defaultManager().fileExistsAtPath(url.path!) {
			self.fetchedImage = UIImage(contentsOfFile:  url.path!)
			return self.fetchedImage
		}
		
		return nil
	}
	
	//=============================================================================================
	//MARK: Private
	
	var fetchedImage: UIImage?
	var localURL: NSURL?
	var isCancelled = false
	var isComplete = false
	
	var imageLocalURL: NSURL {
		if let url = self.localURL { return url }
		
		self.localURL = Hoard.cache.directory.URLByAppendingPathComponent(self.imageFilename)
		return self.localURL!
	}
	
	var imageFilename: String {
		var basic = self.URL.lastPathComponent!
		
		return "\(self.URL.hash)-" + basic
	}
}