//
//  HoardImageCountView.swift
//  Hoard
//
//  Created by Ben Gottlieb on 5/29/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit

public class HoardImageCountView: UILabel {
	public var currentImageIndex = 0 { didSet { self.updateDisplay() }}
	public var numberOfImages = 0 { didSet { self.updateDisplay() }}
	public var formatString = "Photo %d/%d"
	
	class func defaultCountView() -> HoardImageCountView {
		let view = HoardImageCountView(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
		view.backgroundColor = UIColor.darkGrayColor()
		view.layer.borderColor = view.textColor.CGColor
		view.layer.borderWidth = 1.0
		view.textColor = UIColor.lightGrayColor()
		view.textAlignment = .Center
		view.font = UIFont.systemFontOfSize(15.0)
		view.layer.masksToBounds = true
		return view
	}
	
	public func updateDisplay() {
		if self.numberOfImages > 1 {
			self.text = NSString(format: self.formatString, self.currentImageIndex + 1, self.numberOfImages) as String
			self.alpha = 1.0
		} else {
			self.text = ""
			self.alpha = 0.0
		}
		
		let attr = [NSFontAttributeName: self.font]
		let size = NSAttributedString(string: self.text!, attributes: attr).boundingRectWithSize(CGSize(width: 500, height: self.font.lineHeight * 1.5), options: .UsesLineFragmentOrigin, context: nil).size
		
		self.bounds = CGRect(x: 0, y: 0, width: size.width + 20, height: size.height + 6)
		self.layer.cornerRadius = self.bounds.size.height / 2
	}
	
	
}
