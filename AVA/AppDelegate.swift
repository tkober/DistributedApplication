//
//  AppDelegate.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    
    var loggingTextView: NSTextView?
    
    var nodeManager: AVANodeManager?
    
    var setup: AVASetup!
    var topology: AVATopology!
    var onArgumentsProcessed: ((ownPeerName: AVAVertex, isMaster: Bool, topology: AVATopology) -> ())?
    var onNodeStateUpdate: ((state: AVANodeState) -> ())?
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        let arguments = NSProcessInfo.processInfo().arguments
        self.setup = AVAArgumentsParser.sharedInstance.parseArguments(arguments)
        
        if self.setup.peerName == nil {
            print("Missing parameter --peerName")
            exit(2)
        }
        
        if self.setup.isMaster {
            var topologyFilePath: String
            if self.setup.randomTopology {
                self.buildRandomTopology()
                topologyFilePath = "\(self.setup.applicationPackageDirectory)/~random.topology"
                GRAPHVIZ.graphvizFileFromTopology(self.topology).writeToFile(topologyFilePath, atomically: true)
            } else {
                topologyFilePath = self.setup.topologyFilePath!
                self.buildTopologyFromFile()
            }
            self.instantiateTopology(self.topology, ownPeerName: self.setup.peerName!, topologyFilePath: topologyFilePath)
        } else {
            self.buildTopologyFromFile()
        }
        
        self.layoutWindow(CGSizeMake(350, 450), margin: 20)
        
        if let onArgumentsProcessed = self.onArgumentsProcessed {
            onArgumentsProcessed(ownPeerName: self.setup.peerName!, isMaster: self.setup.isMaster, topology: self.topology)
        }
        
        if self.setup.peerName != nil {
            self.nodeManager = AVANodeManager(topology: self.topology, ownPeerName: self.setup.peerName!, logger: self)
            self.nodeManager?.delegate = self
            self.nodeManager?.start()
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    
    // MARK: Topology
    
    
    func buildTopologyFromFile() {
        if let path = self.setup.topologyFilePath {
            self.topology = AVATopology(graphPath: path)
        } else {
            print("Missing parameter --topology")
            exit(2)
        }
    }
    
    
    func buildRandomTopology() {
        if let dimension = self.setup.randomTopologyDimension {
            self.topology = AVATopology(randomWithDimension: dimension)
        } else {
            print("Missing parameter --randomTopologySize")
            exit(2)
        }
    }
    
    
    func terminateTopology() {
        self.nodeManager?.delegate = nil
        self.nodeManager?.broadcastMessage(AVAMessage.terminateMessage(self.setup.peerName!))
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            exit(0)
        }
    }
    
    
    // MARK: Instantiation
    
    
    func instantiateTopology(topology: AVATopology, ownPeerName peerName: String, topologyFilePath: String) {
        let vertices = topology.vertices
        if !vertices.contains(peerName) {
            print("Own peer name is not included in the typology")
            exit(3)
        }
        for vertex in vertices {
            if vertex != peerName {
                instantiateVertex(vertex, fromTopology: topologyFilePath)
            }
        }
    }
    
    
    func instantiateVertex(vertex: AVAVertex, fromTopology topology: String) {
        let task = NSTask()
        task.launchPath = self.setup.applicationPath
        task.arguments = ["--topology", topology, "--peerName", vertex]
        dispatch_async(dispatch_queue_create("peer_\(vertex)_instantiate", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            task.launch()
        }
        print("Instantiated peer '\(vertex)'")
    }
    
    
    // MARK: Layout
    
    
    func layoutWindow(size: CGSize, margin: CGFloat) {
        if let window = NSApplication.sharedApplication().windows.first {
            let visibleScreenFrame = window.screen?.visibleFrame
            let windowesPerRow = UInt(floor((visibleScreenFrame?.size.width)! / (size.width + margin)))
            let index = UInt(self.topology.vertices.sort().indexOf(self.setup.peerName!)!)
            let row = index / windowesPerRow
            let col = index % windowesPerRow
            let x = (margin+size.width)*CGFloat(col) + visibleScreenFrame!.origin.x
            let y = visibleScreenFrame!.size.height - ((margin+size.height)*CGFloat(row)) - size.height + visibleScreenFrame!.origin.y
            let frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            window.setFrame(frame, display: true, animate: false)
            window.makeKeyAndOrderFront(self)
        }
    }

}


extension AppDelegate: AVALogging {
    
    func log(entry: AVALogEntry) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            var attributes: [String: AnyObject]
            switch (entry.level) {
            case .Debug:
                attributes = [NSForegroundColorAttributeName: NSColor.darkGrayColor()]
                break
                
            case .Info:
                attributes = [NSForegroundColorAttributeName: NSColor.blueColor()]
                break
                
            case .Warning:
                attributes = [NSForegroundColorAttributeName: NSColor.orangeColor()]
                break
                
            case .Error:
                attributes = [NSForegroundColorAttributeName: NSColor.redColor()]
                break
            }
            
            let attributedString = NSAttributedString(string: "[\(entry.event.stringValue())]: \(entry.message)\n", attributes: attributes)
            self.loggingTextView?.textStorage?.appendAttributedString(attributedString)
            self.loggingTextView?.scrollRangeToVisible(NSMakeRange((self.loggingTextView?.string?.characters.count)!, 0))
        }
    }
}





// Only for testing
extension AppDelegate: AVANodeManagerDelegate {
    
    func nodeManager(nodeManager: AVANodeManager, stateUpdated state: AVANodeState) {
        if let update = self.onNodeStateUpdate {
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                update(state: state)
            }
        }
    }
    
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveMessage message: AVAMessage) {
        switch message.type {
        case .Terminate:
            self.terminateTopology()
            break
            
        case .ApplicationData:
            break
        }
    }
    
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData: NSData) {
        
    }
}
