//
//  ViewController.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


private enum LocalLogState {
    case Visible;
    case Hidden;
}


class ViewController: NSViewController {
    
    
    // MARK: | Constants
    
    
    private let LOCAL_LOG_SIZE: CGFloat = 120.0

    
    // MARK: | IB Outlets
    
    @IBOutlet private weak var logScrollView: NSScrollView!
    @IBOutlet private weak var nameLabel: NSTextField?
    @IBOutlet private weak var toggleLocalLogButton: NSButton?
    @IBOutlet private weak var localLogHeightConstraint: NSLayoutConstraint?
    @IBOutlet private weak var renderingGraphProgressIndicator: NSProgressIndicator?
    @IBOutlet private weak var graphImageView: NSImageView?
    
    
    
    // MARK: | IB Actions
    
    
    @IBAction private func toggleLocalLogButtonPressed(sender: NSButton) {
        switch self.localLogState {
        case .Visible:
            self.localLogState = .Hidden
            break
            
        case .Hidden:
            self.localLogState = .Visible
            break
        }
        self.updateLocalLog()
    }
    
    
    // MARK: | Local Log
    
    
    private var localLogState = LocalLogState.Hidden
    
    
    func updateLocalLog() {
        switch self.localLogState {
        case .Visible:
            self.localLogHeightConstraint?.constant = LOCAL_LOG_SIZE
            self.toggleLocalLogButton?.state = 1
            break
            
        case .Hidden:
            self.localLogHeightConstraint?.constant = 0
            self.toggleLocalLogButton?.state = 0
            break
        }
    }
    
    
    // MARK: | Graph Image
    
    
    func clearGraphImage() {
        self.graphImageView?.image = nil
        self.renderingGraphProgressIndicator?.hidden = false
        self.renderingGraphProgressIndicator?.startAnimation(self)
    }
    
    
    func updateGraphImage(image: NSImage) {
        self.renderingGraphProgressIndicator?.hidden = true
        self.graphImageView?.image = image
    }
    
    
    // MARK: | Views Lifecylce
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.graphImageView?.wantsLayer = true
        self.graphImageView?.layer?.backgroundColor = NSColor.whiteColor().CGColor
        
        self.updateLocalLog()
        self.clearGraphImage()
        
        let appDelegate = NSApp.delegate as! AppDelegate
        let loggingTextView = logScrollView.contentView.documentView as? NSTextView
        loggingTextView?.editable = false
        appDelegate.loggingTextView = loggingTextView
        appDelegate.onArgumentsProcessed = {(ownPeerName: AVAVertex, isMaster: Bool, topology: AVATopology) in
            let nameSuffix = isMaster ? " (Master)": ""
            self.nameLabel?.stringValue = "Node: \(ownPeerName)\(nameSuffix)"
        
            let tempFilePath = "\(appDelegate.setup.applicationPackageDirectory)/~\(ownPeerName)_\(NSDate().timeIntervalSince1970).render"
            do {
                let dot = GRAPHVIZ.dotFromTopology(topology, vertexDecorator: { (vertex: AVAVertex) -> (color: String, style: String) in
                    return (vertex == ownPeerName ? "blue" : "grey", "solid")
                }, ajacencyDecorator: { (adjacency: AVAAdjacency) -> (direction: AVAGraphvizAdjacencyDirection, color: String, style: String, label: String?) in
                    return (AVAGraphvizAdjacencyDirection.Undirected, "grey", "solid", nil)
                })
                try dot.writeToFile(tempFilePath, atomically: true, encoding: NSUTF8StringEncoding)
                GRAPHVIZ.renderPNGFromFile(tempFilePath) { (image) -> () in
                    if let graphImage = image {
                        self.updateGraphImage(graphImage)
                    }
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(tempFilePath)
                    } catch {
                        
                    }
                }
            } catch {
                
            }
        }
    }

}

