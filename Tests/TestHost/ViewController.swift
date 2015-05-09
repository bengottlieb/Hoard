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
			self.gallery = HoardImageGalleryView(frame: CGRect(x: 50, y: 120, width: self.view.bounds.width - 100, height: 150))
			self.gallery.tapForFullScreen = true
			self.view.addSubview(self.gallery)
			var URLs = [
				NSURL(string: "http://redriverunited.org/wp-content/uploads/2014/01/1.png")!,
				NSURL(string: "http://tomreynolds.com/wp/wp-content/uploads/2014/01/2-graphic-300x300.png")!,
				NSURL(string: "http://vignette3.wikia.nocookie.net/candy-crush-saga/images/9/9a/Red-rounded-with-number-3-md.png/revision/latest?cb=20140802162943")!,
				NSURL(string: "http://cdn.marketplaceimages.windowsphone.com/v8/images/4b85303b-410f-492f-b554-26473010af71?imageType=ws_icon_large")!,
				NSURL(string: "http://static.comicvine.com/uploads/original/11111/111116692/3150494-7873411214-5.jpg.jpg")!,
				NSURL(string: "http://upload.wikimedia.org/wikipedia/commons/5/5a/MRT_Singapore_Destination_6.png")!,
				NSURL(string: "https://clauzzen.files.wordpress.com/2011/11/7.jpg")!,
				NSURL(string: "http://www.donewaiting.com/wp-content/uploads/2011/01/8ball.jpg")!,
				NSURL(string: "http://triadstrategies.typepad.com/.a/6a0120a6abf659970b015436794df1970c-pi")!,
				NSURL(string: "http://www.nature.com/polopoly_fs/7.14368.1387365090!/image/natures-10-lead-2.jpg_gen/derivatives/landscape_630/natures-10-lead-2.jpg")!
			]
			
			for i in 0...30 {
				//URLs.append(NSURL(string: "http://lorempixel.com/\((rand() % 400 + 30))/\((rand() % 400 + 40))/")!)
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

