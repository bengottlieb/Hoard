//
//  URL+Hoard.swift
//  Hoard
//
//  Created by Ben Gottlieb on 12/1/18.
//  Copyright © 2018 Stand Alone, inc. All rights reserved.
//

import Foundation

extension URL {
	var lastModifiedOnDiskAt: Date? {
		if !self.isFileURL { return nil }
		do {
			let info = try FileManager.default.attributesOfItem(atPath: self.path)
			
			return info[.modificationDate] as? Date ?? info[.creationDate] as? Date
		} catch {
			return nil
		}
	}
}
