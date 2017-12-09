//
//  IncomingImage.swift
//  Hoard
//
//  Created by Ben Gottlieb on 6/21/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import UIKit
import Plug

public class IncomingImage {
	var incoming: Incoming<UIImage>
	public init(url: URL, method: Plug.Method = .GET, parameters: Plug.Parameters? = nil, deferredStart: Bool = false) {
		self.incoming = Incoming<UIImage>(url: url, method: method, parameters: parameters, deferredStart: true) { data in
			return data.image
		}
		
		if let image = Cache.defaultImageCache.fetchImage(for: url) {
			self.incoming.result = image
			self.incoming.isComplete = true
		} else if !deferredStart {
			self.start()
		}
	}
	
	public func resolved(_ closure: @escaping (UIImage?) -> Void) { self.incoming.resolved(closure) }
	public func start() { self.incoming.start() }
	public var result: UIImage? { return self.incoming.result }
}
