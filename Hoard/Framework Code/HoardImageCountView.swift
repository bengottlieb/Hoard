//
//  ImageCountView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 5/29/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

extension Hoard {
	open class ImageCountView: UILabel {
		open var currentImageIndex = 0 { didSet { self.updateDisplay() }}
		open var numberOfImages = 0 { didSet { self.updateDisplay() }}
		open var formatString = "Photo %d/%d"
		
		class func defaultCountView() -> ImageCountView {
			let view = ImageCountView(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
			view.backgroundColor = UIColor.darkGray
			view.layer.borderColor = view.textColor.cgColor
			view.layer.borderWidth = 1.0
			view.textColor = UIColor.lightGray
			view.textAlignment = .center
			view.font = UIFont.systemFont(ofSize: 15.0)
			view.layer.masksToBounds = true
			return view
		}
		
		open func updateDisplay() {
			if self.numberOfImages > 1 {
				self.text = NSString(format: self.formatString as NSString, self.currentImageIndex + 1, self.numberOfImages) as String
				self.alpha = 1.0
			} else {
				self.text = ""
				self.alpha = 0.0
			}
			
			let attr = [NSFontAttributeName: self.font]
			let size = NSAttributedString(string: self.text!, attributes: attr).boundingRect(with: CGSize(width: 500, height: self.font.lineHeight * 1.5), options: .usesLineFragmentOrigin, context: nil).size
			
			self.bounds = CGRect(x: 0, y: 0, width: size.width + 20, height: size.height + 6)
			self.layer.cornerRadius = self.bounds.size.height / 2
		}
		
	}
}
