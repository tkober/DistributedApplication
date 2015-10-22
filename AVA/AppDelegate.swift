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
    
    var serviceManager: AVAServiceManager?
    
    var setup: AVASetup!
    var topology: AVATopology!
    var onArgumentsProcessed: ((setup: AVASetup) -> ())?
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        let arguments = NSProcessInfo.processInfo().arguments
        self.setup = AVAArgumentsParser.sharedInstance.parseArguments(arguments)
        
        if self.setup.peerName == nil {
            print("Missing parameter --peerName")
            exit(2)
        }
        if let onArgumentsProcessed = self.onArgumentsProcessed {
            onArgumentsProcessed(setup: self.setup)
        }
        
        
        if self.setup.isMaster {
            if self.setup.randomTopology {
                self.buildRandomTopology()
            } else {
                self.buildTopologyFromFile()
                self.instantiateTopology(self.topology, ownPeerName: self.setup.peerName!)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (Int64)(10 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                    self.serviceManager?.bla()
                }
            }
        } else {
            self.buildTopologyFromFile()
        }
        
        if self.setup.peerName != nil {
            self.serviceManager = AVAServiceManager(topology: self.topology, ownPeerName: self.setup.peerName!, logger: self)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

}


extension AppDelegate {
    
    func instantiateTopology(topology: AVATopology, ownPeerName peerName: String) {
        let vertices = topology.vertices
        if !vertices.contains(peerName) {
            print("Own peer name is not included in the typology")
            exit(3)
        }
        for vertex in vertices {
            if vertex != peerName {
                instantiateVertex(vertex, fromTopology: self.setup.topologyFilePath!)
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
    
}


extension AppDelegate {
    
    func buildTopologyFromFile() {
        if let path = self.setup.topologyFilePath {
            self.topology = AVATopology(graphPath: path)
        } else {
            print("Missing parameter --topology")
            exit(2)
        }
    }
    
    
    func buildRandomTopology() {
        if let size = self.setup.randomTopologySize {
            print("TODO: Build random topology of size \(size)")
        } else {
            print("Missing parameter --randomTopologySize")
            exit(2)
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
//        [self.outputTextView scrollRangeToVisible:NSMakeRange([[self.outputTextView string] length], 0)];
    }
}