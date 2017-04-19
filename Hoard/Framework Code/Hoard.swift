//
//  Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 2/9/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CrossPlatformKit

@objc public protocol HoardImageSource {
	func generateImage(for: URL) -> UXImage?
	func isFastImageGenerator(for: URL) -> Bool
}

open class HoardState: NSObject {
	public enum DebugLevel: Int { case none, low, high }
	open static var instance = HoardState()
	
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
	
	open static var defaultImageCache = Cache.cache(for: HoardState.mainImageCacheKey)
	open static let mainImageCacheKey = "main-hoard-cache"
	
	//=============================================================================================
	//MARK: Private
	
	class func addMaintenance(block: @escaping () -> Void) {
		HoardState.instance.maintenanceQueue.addOperation(block)
	}
	
	func enqueue(pending: PendingImage? = nil) {
		if let pending = pending { self.pending.append(pending) }
		if self.active.count < self.maxConcurrentDownloads && self.pending.count > 0 {
			let next = self.pending[0]
			self.active.insert(next)
			self.pending.remove(at: 0)
			next.start()
		}
	}
	
	func findExistingConnection(with url: URL) -> PendingImage? {
		var found = self.pending.filter({ $0.url == url })
		if found.count > 0 { return found[0] }
		
		found = Array(self.active).filter({ $0.url == url })
		if found.count > 0 { return found[0] }
		
		return nil
	}
	
	func completed(image: PendingImage) {
		_ = self.pending.remove(image)
		
		if image.isComplete {
			self.active.remove(image)
		}
		self.serializerQueue.addOperation {
			self.enqueue()
		}
	}
	
	func cancel(image: PendingImage) {
		self.completed(image: image)
	}
	
	let serializerQueue = OperationQueue()
	let maintenanceQueue = OperationQueue()
	let generationQueue = OperationQueue()

}
