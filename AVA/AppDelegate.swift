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
    
    let loggingQueue: dispatch_queue_t = dispatch_queue_create("ava(\(NSProcessInfo.processInfo().processIdentifier)).app_delegate.logging)", DISPATCH_QUEUE_SERIAL)
    
    lazy var logfilePath: String = "\(self.setup.applicationPackageDirectory)/~\(self.setup.peerName!).dlog"
    var loggingStream: NSOutputStream?
    
    var service: AVAService?
    var messageBuffer = [AVAMessage]()
    
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let arguments = NSProcessInfo.processInfo().arguments
        self.setup = AVAArgumentsParser.sharedInstance.parseArguments(arguments)
        
        if self.setup.peerName == nil {
            print("Missing parameter --peerName")
            exit(2)
        }
        
        self.setupLogger()
        self.service = self.serviceFromSetup(self.setup)
        
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
            self.instantiateTopology(self.topology, ownPeerName: self.setup.peerName!, topologyFilePath: topologyFilePath, withServiceOfType: self.setup.service)
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
    
    
    func instantiateTopology(topology: AVATopology, ownPeerName peerName: String, topologyFilePath: String, withServiceOfType serviceType: AVAServiceType) {
        let vertices = topology.vertices
        if !vertices.contains(peerName) {
            print("Own peer name is not included in the typology")
            exit(3)
        }
        for vertex in vertices {
            if vertex != peerName {
                instantiateVertex(vertex, fromTopology: topologyFilePath, withServiceOfType: serviceType)
            }
        }
    }
    
    
    func instantiateVertex(vertex: AVAVertex, fromTopology topology: String, withServiceOfType serviceType: AVAServiceType) {
        let task = NSTask()
        task.launchPath = self.setup.applicationPath
        task.arguments = ["--topology", topology, "--peerName", vertex]
        task.arguments?.appendContentsOf(serviceType.nodeInstantiationParametersFromSetup(self.setup))
        dispatch_async(dispatch_queue_create("peer_\(vertex)_instantiate", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            task.launch()
        }
        self.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.Processing, peer: self.setup.peerName!, description: "Instantiated peer '\(vertex)'", remotePeer: vertex))
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
        dispatch_async(self.loggingQueue) { () -> Void in
            if let stream = self.loggingStream, log = entry.stringValue() {
                stream.write("\(log),\n")
            }
        }
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            let attributedString = NSAttributedString(string: "[\(entry.event.stringValue())]: \(entry.entryDescription)\n", attributes: entry.level.attributes())
            self.loggingTextView?.textStorage?.appendAttributedString(attributedString)
            self.loggingTextView?.scrollRangeToVisible(NSMakeRange((self.loggingTextView?.string?.characters.count)!, 0))
        }
    }
    
    
    func setupLogger() {
        if (NSFileManager.defaultManager().fileExistsAtPath(logfilePath)) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(logfilePath)
            } catch {
                
            }
        }
        loggingStream = NSOutputStream(toFileAtPath: self.logfilePath, append: true)
        loggingStream?.open()
    }
}


extension AppDelegate: AVANodeManagerDelegate {
    
    func nodeManager(nodeManager: AVANodeManager, stateUpdated state: AVANodeState) {
        if state.disconnectedPeers.count == 0 {
            if let service = self.service {
                service.startWithBufferedMessage(self.messageBuffer)
            }
        }
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
            if let service = self.service {
                service.nodeManager(nodeManager, didReceiveApplicationDataMessage: message)
            } else {
                self.messageBuffer.append(message)
            }
            break
        }
    }
    
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData, fromPeer peer: AVAVertex) {
        
    }
}


extension AppDelegate {
    
    func serviceFromSetup(setup: AVASetup) -> AVAService {
        switch setup.service! {
        case AVAServiceType.Uebung1:
            return AVAUebung1(setup: setup)
            
        }
    }
    
}


extension NSOutputStream {
    
    func write(string: String, encoding: NSStringEncoding = NSUTF8StringEncoding, allowLossyConversion: Bool = true) -> Int {
        if let data = string.dataUsingEncoding(encoding, allowLossyConversion: allowLossyConversion) {
            var bytes = UnsafePointer<UInt8>(data.bytes)
            var bytesRemaining = data.length
            var totalBytesWritten = 0
            
            while bytesRemaining > 0 {
                let bytesWritten = self.write(bytes, maxLength: bytesRemaining)
                if bytesWritten < 0 {
                    return -1
                }
                
                bytesRemaining -= bytesWritten
                bytes += bytesWritten
                totalBytesWritten += bytesWritten
            }
            
            return totalBytesWritten
        }
        
        return -1
    }
    
}