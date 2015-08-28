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
		self.updateDirectory()
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
	
	public var directory: NSURL = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(
		.LibraryDirectory, .UserDomainMask, true)[0], isDirectory: true).URLByAppendingPathComponent("CachedImages") { didSet {
			self.updateDirectory()
		}}
	
	func requestImageURL(url: NSURL, source: HoardImageSource? = nil, completion: ImageCompletion? = nil) -> PendingImage {
		let pending = PendingImage(url: url, completion: completion)
		
		if pending.isCachedAvailable {
			pending.complete(true)
		} else if let source = source {
			pending.fetchedImage = source.generateImageForURL(url)
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
	
	public func clearCache() {
		do {
			try NSFileManager.defaultManager().removeItemAtURL(self.directory)
		} catch let error as NSError {
			print("Error while clearing Hoard cache: \(error)")
		}
		
		self.updateDirectory()
	}
	

	//=============================================================================================
	//MARK: Private
	func updateDirectory() {
		do {
			try NSFileManager.defaultManager().createDirectoryAtURL(self.directory, withIntermediateDirectories: true, attributes: nil)
		} catch let error as NSError {
			print("Unable to setup images directory at \(self.directory): \(error)")
		}
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
		self.queue.addOperationWithBlock {
			self.enqueue()
		}
	}
	
	func cancelPending(image: PendingImage) {
		self.completedPending(image)
	}
	
	let queue: NSOperationQueue = { var queue = NSOperationQueue(); queue.maxConcurrentOperationCount = 1; return queue }()

}