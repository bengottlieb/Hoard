//
//  Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 2/9/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

@objc public protocol HoardImageSource {
	func generateImage(for: URL) -> UIImage?
	func isFastImageGenerator(for: URL) -> Bool
}

open class Hoard: NSObject {
	public enum DebugLevel: Int { case none, low, high }
	open static var instance = Hoard()
	
	override init() {
		serializerQueue.maxConcurrentOperationCount = 1;
		serializerQueue.qualityOfService = .userInitiated
		
		maintenanceQueue.maxConcurrentOperationCount = 1;
		maintenanceQueue.qualityOfService = .background
		
		generationQueue.qualityOfService = .userInteractive
		
		super.init()
	}
	
	class func main_thread(_ block: @escaping () -> Void) {
		if Thread.isMainThread {
			block()
		} else {
			DispatchQueue.main.async(execute: block)
		}
	}
	
	open var maxConcurrentDownloads = 400
	open var active = Set<PendingImage>()
	open var pending = Array<PendingImage>()
	open static var debugLevel = DebugLevel.none
	open weak var source: HoardImageSource?
	
	open static var defaultImageCache = Cache.cacheForKey(Hoard.mainImageCacheKey)
	open static let mainImageCacheKey = "main-hoard-cache"
	
	//=============================================================================================
	//MARK: Private
	
	class func addMaintenanceBlock(_ block: @escaping () -> Void) {
		Hoard.instance.maintenanceQueue.addOperation(block)
	}
	
	func enqueue(_ pending: PendingImage? = nil) {
		if let pending = pending { self.pending.append(pending) }
		if self.active.count < self.maxConcurrentDownloads && self.pending.count > 0 {
			let next = self.pending[0]
			self.active.insert(next)
			self.pending.remove(at: 0)
			next.start()
		}
	}
	
	func findExistingConnectionWithURL(_ url: URL) -> PendingImage? {
		var found = self.pending.filter({ $0.URL as URL == url })
		if found.count > 0 { return found[0] }
		
		found = Array(self.active).filter({ $0.URL as URL == url })
		if found.count > 0 { return found[0] }
		
		return nil
	}
	
	func completedPending(_ image: PendingImage) {
		_ = self.pending.remove(image)
		
		if image.isComplete {
			self.active.remove(image)
		}
		self.serializerQueue.addOperation {
			self.enqueue()
		}
	}
	
	func cancelPending(_ image: PendingImage) {
		self.completedPending(image)
	}
	
	let serializerQueue = OperationQueue()
	let maintenanceQueue = OperationQueue()
	let generationQueue = OperationQueue()

}
