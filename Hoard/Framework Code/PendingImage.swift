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
			
			data.writeToURL(self.imageLocalURL, atomically: true)
			//println("Finished downloading from \(self.URL)")
		}).error({ conn, error in
			print("error downloading from \(self.URL): \(error)")
			if Hoard.debugging { conn.log() }
			self.error = error
			self.complete(false)
		}).start()
	}
	
	public func cancel() {
		Hoard.cache.cancelPending(self)
		self.isCancelled = true
	}
	
	var isCachedAvailable: Bool {
		if self.fetchedImage != nil { return true }
		
		if let path = self.imageLocalURL.path where NSFileManager.defaultManager().fileExistsAtPath(path) { return true }
		
		return false
	}
	
	func complete(fromCache: Bool, image: UIImage? = nil) {
		self.isComplete = true
		if !self.isCancelled {
			for dupe in self.dupes {
				dupe.complete(fromCache, image: self.image)
			}
			dispatch_async(dispatch_get_main_queue()) {
				if let completion = self.completion {
					completion(image: self.image ?? image, error: self.error, fromCache: fromCache)
				}
			}
		}
		
		if image == nil { Hoard.cache.completedPending(self) }
	}
	
	public var image: UIImage? {
		if let image = self.fetchedImage { return image }
				
		if let path = self.imageLocalURL.path where NSFileManager.defaultManager().fileExistsAtPath(path) {
			self.fetchedImage = UIImage(contentsOfFile: path)
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
		let basic = self.URL.lastPathComponent!
		
		return "\(self.URL.hash)-" + basic
	}
}