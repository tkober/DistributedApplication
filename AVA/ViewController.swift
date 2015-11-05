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
    
    
    // MARK: | Segues
    
    
    private let SHOW_DISTRIUBTED_LOG_SEGUE_ID = "showDistributedLog"

    
    // MARK: | IB Outlets
    
    @IBOutlet private weak var logScrollView: NSScrollView!
    @IBOutlet private weak var nameLabel: NSTextField?
    @IBOutlet private weak var toggleLocalLogButton: NSButton?
    @IBOutlet private weak var localLogHeightConstraint: NSLayoutConstraint?
    @IBOutlet private weak var renderingGraphProgressIndicator: NSProgressIndicator?
    @IBOutlet private weak var graphImageView: NSImageView?
    @IBOutlet private weak var terminateButton: NSButton?
    @IBOutlet private weak var showDistributedLogButton: NSButton?
    
    
    
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
    
    
    @IBAction private func terminateButtonPressed(sender: NSButton) {
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.terminateTopology()
    }
    
    
    // MARK: | Local Log
    
    
    private var localLogState = LocalLogState.Visible
    
    
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
        let imageViewWith = self.graphImageView!.frame.size.width
        let imageViewHeight = self.graphImageView!.frame.size.height
        let ratio = image.size.width / image.size.height
        if (imageViewHeight * ratio) <= imageViewWith {
            image.size = CGSizeMake(imageViewHeight * ratio, imageViewHeight)
        } else {
            image.size = CGSizeMake(imageViewWith, imageViewWith / ratio)
        }
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
        appDelegate.onArgumentsProcessed = self.onArgumentProcessing
        appDelegate.onNodeStateUpdate = self.onNodeStateUpdate
    }
    
    
    func onArgumentProcessing(ownPeerName: AVAVertex, isMaster: Bool, topology: AVATopology) {
        let appDelegate = NSApp.delegate as! AppDelegate
        let nameSuffix = isMaster ? " (Master)": ""
        self.nameLabel?.stringValue = "Node: \(ownPeerName)\(nameSuffix)"
        self.terminateButton?.hidden = !isMaster
        self.showDistributedLogButton?.hidden = !isMaster
        
        let tempFilePath = "\(appDelegate.setup.applicationPackageDirectory)/~\(ownPeerName)_\(NSDate().timeIntervalSince1970).render"
        do {
            let dot = GRAPHVIZ.dotFromTopology(topology, vertexDecorator: { (vertex: AVAVertex) -> AVAGraphvizVertexDecoration in
                return (vertex == ownPeerName ? AVAGraphvizBlue : AVAGraphvizGrey, AVAGraphvizSolid)
            }, ajacencyDecorator: { (adjacency: AVAAdjacency) -> AVAGraphvizAdjacencyDecoration in
                if adjacency.v1 == ownPeerName || adjacency.v2 == ownPeerName {
                    return (AVAGraphvizAdjacencyDirection.Undirected, AVAGraphvizBlue, AVAGraphvizDotted, nil)
                } else {
                    return (AVAGraphvizAdjacencyDirection.Undirected, AVAGraphvizGrey, AVAGraphvizSolid, nil)
                }
            })
            try dot.writeToFile(tempFilePath, atomically: true, encoding: NSUTF8StringEncoding)
            self.renderAndUpdateGraphImage(tempFilePath)
        } catch {
            
        }
    }
    
    
    func onNodeStateUpdate(state: AVANodeState) {
        let appDelegate = NSApp.delegate as! AppDelegate
        let ownPeerName = appDelegate.setup.peerName!
        let topology = appDelegate.topology
        let tempFilePath = "\(appDelegate.setup.applicationPackageDirectory)/~\(ownPeerName)_\(NSDate().timeIntervalSince1970).render"
        
        do {
            let dot = GRAPHVIZ.dotFromTopology(topology, vertexDecorator: { (vertex: AVAVertex) -> AVAGraphvizVertexDecoration in
                return (vertex == ownPeerName ? AVAGraphvizBlue : AVAGraphvizGrey, AVAGraphvizSolid)
            }, ajacencyDecorator: { (adjacency: AVAAdjacency) -> AVAGraphvizAdjacencyDecoration in
                if adjacency.v1 == ownPeerName || adjacency.v2 == ownPeerName {
                    let vertex = adjacency.v1 == ownPeerName ? adjacency.v2 : adjacency.v1
                    let style = state.connectedPeers.contains(vertex) ? AVAGraphvizSolid : AVAGraphvizDotted
                    return (AVAGraphvizAdjacencyDirection.Undirected, AVAGraphvizBlue, style, nil)
                } else {
                    return (AVAGraphvizAdjacencyDirection.Undirected, AVAGraphvizGrey, AVAGraphvizSolid, nil)
                }
            })
            try dot.writeToFile(tempFilePath, atomically: true, encoding: NSUTF8StringEncoding)
            self.renderAndUpdateGraphImage(tempFilePath)
        } catch {
            
        }
    }
    
    
    func renderAndUpdateGraphImage(tempFilePath: String) {
        GRAPHVIZ.renderPNGFromFile(tempFilePath) { (image) -> () in
            if let graphImage = image {
                self.updateGraphImage(graphImage)
            }
            do {
                try NSFileManager.defaultManager().removeItemAtPath(tempFilePath)
            } catch {
                
            }
        }
    }
    
    
    // MARK: | Storyboard
    
    
    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == SHOW_DISTRIUBTED_LOG_SEGUE_ID {
            let logViewController = segue.destinationController as! AVALogViewController
            let appDelegate = NSApp.delegate as! AppDelegate
            logViewController.gatherLogs(appDelegate.setup.applicationPackageDirectory)
        }
    }

}

