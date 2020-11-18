//
//  Delegates.swift
//  Hoard
//
//  Created by Ben Gottlieb on 12/11/17.
//  Copyright © 2017 Stand Alone, inc. All rights reserved.
//

import Foundation
import Plug

public protocol HoardCacheDelegate: class {
	func connection(for: URL) -> Connection?
}

extension HoardCacheDelegate {
	func connection(for url: URL) -> Connection? { return Connection(url: url) }
}

