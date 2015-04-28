//
//  Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 2/9/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import SA_Swift

public class Hoard: NSObject {
	public class var cache: Hoard { struct s { static let manager = Hoard() }; return s.manager }
	
	override init() {
		super.init()
		self.updateDirectory()
	}
	
	public var maxConcurrentDownloads = 400
	public var active = Set<PendingImage>()
	public var pending = Array<PendingImage>()
	
	public var directory: NSURL = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(
		.LibraryDirectory, .UserDomainMask, true)[0] as! String, isDirectory: true)!.URLByAppendingPathComponent("CachedImages") { didSet {
			self.updateDirectory()
		}}
	
	func requestImageURL(url: NSURL, completion: ImageCompletion? = nil) -> PendingImage {
		var pending = PendingImage(url: url, completion: completion)
		
		self.queue.addOperationWithBlock {
			if pending.isCachedAvailable {
				pending.complete()
			} else if let existing = self.findExistingConnectionWithURL(url) {
				existing.dupes.append(pending)
			} else {
				self.enqueue(pending)
			}
		}
		
		return pending
	}
	
	public func clearCache() {
		var error: NSError?
		
		if !NSFileManager.defaultManager().removeItemAtURL(self.directory, error: &error) {
			println("Error while clearing Hoard cache: \(error)")
		}
		
		self.updateDirectory()
	}
	

	//=============================================================================================
	//MARK: Private
	func updateDirectory() {
		var error: NSError?
		if !NSFileManager.defaultManager().createDirectoryAtURL(self.directory, withIntermediateDirectories: true, attributes: nil, error: &error) {
			println("Unable to setup images directory at \(self.directory): \(error!)")
		}
	}
	
	func enqueue(_ pending: PendingImage? = nil) {
		if let pending = pending { self.pending.append(pending) }
		if self.active.count < self.maxConcurrentDownloads && self.pending.count > 0 {
			var next = self.pending[0]
			self.active.insert(next)
			self.pending.removeAtIndex(0)
			next.start()
		}
	}
	
	func findExistingConnectionWithURL(url: NSURL) -> PendingImage? {
		var found = filter(self.pending, { $0.URL == url })
		if found.count > 0 { return found[0] }
		
		found = filter(Array(self.active), { $0.URL == url })
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
	
	let queue = NSOperationQueue(serial: true)

}