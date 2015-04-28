//
//  ViewController.swift
//  Hoard
//
//  Created by Ben Gottlieb on 2/9/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import UIKit
import Hoard

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.view.backgroundColor = UIColor.greenColor()
	
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	var gallery: HoardImageGalleryView!
	
	override func viewDidLayoutSubviews() {
		if self.gallery == nil {
			self.gallery = HoardImageGalleryView(frame: self.view.bounds.rectByInsetting(dx: 20, dy: 30))
			self.gallery.tapForFullScreen = true
			self.view.addSubview(self.gallery)
			var URLs: [NSURL] = []
			
			for i in 0...30 {
				URLs.append(NSURL(string: "http://lorempixel.com/\((rand() % 40 + 300))/\((rand() % 40 + 538))/")!)
			}
			
			self.gallery.imageURLs = URLs
		}
	}
	
	func layoutTiles() {
		if self.view.subviews.count > 5 { return }
		
		var size = self.view.frame.size
		var width: CGFloat = 80
		var height: CGFloat = 50
		var top: CGFloat = 0, left: CGFloat = 0
		var added = 0
		
		while top < size.height {
			var frame = CGRect(x: left, y: top, width: width, height: height)
			var view = HoardImageView(frame: frame)
			
			view.backgroundColor = UIColor.blackColor()
			view.contentMode = .ScaleAspectFill
			view.tapForFullScreen = true
			view.useDeviceOrientation = false
			view.URL = NSURL(string: "http://lorempixel.com/\((rand() % 32 + 80))/\((rand() % 32 + 50))/")
			self.view.addSubview(view)
			
			left += width
			
			if left > size.width {
				left = 0
				top += height
			}
			added++
		}
		println("added \(added) views")
	}
}

