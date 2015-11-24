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

    /**
     * Die NSTextView, in der der lokale Log des Knoten angezeigt werden soll.
     */
    var loggingTextView: NSTextView?

    /**
     * Der AVANodeManager des Knoten zur Kommunikation mit den Nachbarn.
     */
    var nodeManager: AVANodeManager?
    
    /**
     * Das setup des Knoten aus den Uebergabe-Parametern.
     */
    var setup: AVASetup!
    
    /**
     * Die Topologie, die aus dem Setup gelesen wurde.
     */
    var topology: AVATopology!
    
    /**
     * Wird aufgerufen, sobald alle Uebergabe-Parameter verarbeitet wurden.
     */
    var onArgumentsProcessed: ((ownPeerName: AVAVertexName, isMaster: Bool, topology: AVATopology) -> ())?
    
    /**
     * Wird aufgerufen, wenn sich der Status des NodeManagers aendert.
     */
    var onNodeStateUpdate: ((state: AVANodeState) -> ())?
    
    /**
     * Serielle Dispatch-Queue zum Schreiben der Logs.
     */
    let loggingQueue: dispatch_queue_t = dispatch_queue_create("ava(\(NSProcessInfo.processInfo().processIdentifier)).app_delegate.logging)", DISPATCH_QUEUE_SERIAL)
    
    /**
     * Der Pfad zum Log-File des aktuellen Knoten.
     */
    lazy var logfilePath: String = "\(self.setup.applicationPackageDirectory)/~\(self.setup.peerName!).dlog"
    
    /**
     * NSOutputStream zum Log-File des aktuellen Knoten.
     */
    var loggingStream: NSOutputStream?
    
    /**
     * Der Service, der vom aktuellen Knonten bereitgestellt wird.
     */
    var service: AVAService?
    
    /**
     * Hier werde Nachrichten zwischengespeichert, die Eintreffen, bevor der Knoten alle seine Nachbarn verbunden hat. Der Service wird anschliessend mit diesem Buffer gestartet.
     */
    var messageBuffer = [AVAMessage]()
    
    
    // MARK: | NSApplicationDelegate
    
    
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
    
    
    // MARK: Topology
    
    
    /**
    
     Erstellt eine AVATopology-Instanz aus dem Setup.
    
     */
    func buildTopologyFromFile() {
        if let path = self.setup.topologyFilePath {
            do {
                self.topology = try AVATopology(graphPath: path)
            } catch AVAVertexError.ambiguousVertexDefinition(let vertex) {
                print("Ambiguous definition of vertex \(vertex)")
                exit(5)
            } catch {
                print("Unable to process input topology")
                exit(2)
            }
        } else {
            print("Missing parameter --topology")
            exit(2)
        }
    }
    
    
    /**
     
     Erstellt eine zufaellige Toptologie mit der Dimension aus dem Setup.
     
     */
    func buildRandomTopology() {
        if let dimension = self.setup.randomTopologyDimension {
            self.topology = AVATopology(randomWithDimension: dimension)
        } else {
            print("Missing parameter --randomTopologySize")
            exit(2)
        }
    }
    
         // MARK: Instantiation
    /**
     
     Sendet eine Terminate-Message an alle Nachbarn und beendet den Prozess mit einer Verzögerung von 1 Sekunde.
     
     */
    func terminateTopology() {
        self.nodeManager?.delegate = nil
        self.nodeManager?.broadcastMessage(AVAMessage.terminateMessage(self.setup.peerName!))
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            exit(0)
        }
    }
    
    

    
    
    /**
     
     Erstellt alle anderen Knoten aus einer gegebenen Topologie.
    
     - parameters:
     
        - topology: Die AVATopology, die aus dem Setup erstellt wurde.
     
        - peerName: Der Name des eigenen Knoten.
     
        - topologyFilePath: Der Pfad, unter welchem die Beschreibung der zu erstellenen Topologie liegt.
     
        - serviceType: Der Service, welchen die Knoten der Topologie bereitstellen sollen.
    
    
     */
    func instantiateTopology(topology: AVATopology, ownPeerName peerName: String, topologyFilePath: String, withServiceOfType serviceType: AVAServiceType) {
        let vertices = topology.vertices
        for vertex in vertices {
            if vertex.name == peerName {
                for vertex in vertices {
                    if vertex.name != peerName {
                        instantiateVertex(vertex, fromTopology: topologyFilePath, withServiceOfType: serviceType)
                    }
                }
                return
            }
        }
        print("Own peer name is not included in the typology")
        exit(3)
    }
    
    
    /**
     
     Instanziiert einen neuen Knoten.
     
     - parameters:
        
        - vertex: Der Name des Knoten.
     
        - topology: Der Pfad zur Beschreibung der Topologie.
     
        - serviceType: Der Service, welchen die Knoten der Topologie bereitstellen sollen.
     
     */
    func instantiateVertex(vertex: AVAVertex, fromTopology topology: String, withServiceOfType serviceType: AVAServiceType) {
        let task = NSTask()
        task.launchPath = self.setup.applicationPath
        task.arguments = ["--topology", topology, "--peerName", vertex.name]
        task.arguments?.appendContentsOf(serviceType.nodeInstantiationParametersFromSetup(self.setup))
        dispatch_async(dispatch_queue_create("peer_\(vertex)_instantiate", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            task.launch()
        }
        self.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.Processing, peer: self.setup.peerName!, description: "Instantiated peer '\(vertex)'", remotePeer: vertex.name))
    }
    
    
    // MARK: Layout
    
    
    /**
    
     Positioniert das Fenster der Anwendung so, dass es schoen aussieht.
    
     */
    func layoutWindow(size: CGSize, margin: CGFloat) {
        if let window = NSApplication.sharedApplication().windows.first {
            let visibleScreenFrame = window.screen?.visibleFrame
            let windowesPerRow = UInt(floor((visibleScreenFrame?.size.width)! / (size.width + margin)))
            
            let verticesSorted = self.topology.vertices.sort({ (a: AVAVertex, b: AVAVertex) -> Bool in
                return a.name < b.name
            })
            var index: UInt = 0
            for var i = 0; i < verticesSorted.count; i++ {
                if self.setup.peerName! == verticesSorted[i].name {
                    index = UInt(i)
                    break
                }
            }
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


/**
 
 Implementiert das AVALogging Protokoll.
 
 */
extension AppDelegate: AVALogging {
    
    func log(entry: AVALogEntry) {
        dispatch_async(self.loggingQueue) { () -> Void in
            if let stream = self.loggingStream, log = entry.jsonStringValue() {
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


/**
 
 Implementiert das AVANodeManagerDelegate Protokoll.
 
 */
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
    

    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData, fromPeer peer: AVAVertexName) {
        
    }
}


extension AppDelegate {
    
    /**
     
     Erstellt den entrechenden Service aus dem Setup.
     
     - parameters:
        - setup: Das AVASetup, welches aus den Uebergabe-Parametern erstellt wurde.
     
     - returns: Den entsprechenden AVAService.
     
     */
    func serviceFromSetup(setup: AVASetup) -> AVAService {
        switch setup.service! {
        case AVAServiceType.Uebung1:
            return AVAUebung1(setup: setup)
            
        }
    }
    
}


/**
 
 Kategorische Erweiterung, die NSOutputStream um eine Methode zum einfachen Schreiben einse Strings erweitert.
 
 */
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