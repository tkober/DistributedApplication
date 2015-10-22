//
//  ViewController.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet weak var nameLabel: NSTextField?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.loggingTextView = logScrollView.contentView.documentView as? NSTextView
        appDelegate.onArgumentsProcessed = {(setup: AVASetup) in
            self.nameLabel?.stringValue = setup.peerName!
        }
    }

}

