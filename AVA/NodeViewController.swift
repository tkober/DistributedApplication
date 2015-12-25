//
//  NodeViewController.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


class NodeViewController: NSViewController {
    
    
    static let STORYBOARD_ID = "NodeViewController"

    
    // MARK: | IB Outlets
    
    @IBOutlet private weak var logScrollView: NSScrollView!
    @IBOutlet private weak var nameLabel: NSTextField?
    
    
    // MARK: | Views Lifecylce
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = NSApp.delegate as! AppDelegate
        let loggingTextView = logScrollView.contentView.documentView as? NSTextView
        loggingTextView?.editable = false
        appDelegate.loggingTextView = loggingTextView
        appDelegate.onArgumentsProcessed = self.onArgumentProcessing
    }
    
    
    // MARK: | Argument Processing
    
    func onArgumentProcessing(ownPeerName: AVAVertexName, isMaster: Bool, topology: AVATopology) {
        let nameSuffix = isMaster ? " (Master)": ""
        self.nameLabel?.stringValue = "Node: \(ownPeerName)\(nameSuffix)"
    }
}

