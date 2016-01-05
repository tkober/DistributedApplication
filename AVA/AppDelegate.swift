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
    
    
    lazy var initialWindow: NSWindow = NSApplication.sharedApplication().windows.first!
    
    
    lazy var storyboard: NSStoryboard = NSStoryboard(name: "Main", bundle: nil)
    
    
    // MARK: | NSApplicationDelegate
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let arguments = NSProcessInfo.processInfo().arguments
        self.setup = AVAArgumentsParser.sharedInstance.parseArguments(arguments)
        
        if (self.setup.isObserver) {
            self.setupAsObserver()
        } else {
            self.setupAsNode()
        }
        
        if let onArgumentsProcessed = self.onArgumentsProcessed {
            onArgumentsProcessed(ownPeerName: self.setup.peerName!, isMaster: self.setup.isObserver, topology: self.topology)
        }
        
        if self.setup.peerName != nil {
            self.nodeManager = AVANodeManager(topology: self.topology, ownPeerName: self.setup.peerName!, logger: self)
            self.nodeManager?.delegate = self
            self.nodeManager?.start()
        }
    }
    
    
    // MARK: | Run Mode
    
    
    func setupAsObserver() {
        self.setup.peerName = OBSERVER_NAME
        var topologyFilePath: String
        self.setupLogger()
        
        if self.setup.randomTopology {
            self.buildRandomTopology()
            topologyFilePath = "\(self.setup.applicationPackageDirectory)/~random.topology"
            do {
                try self.topology.toData().writeToFile(topologyFilePath, atomically: true)
            } catch {
                exit(6)
            }
        } else {
            topologyFilePath = self.setup.topologyFilePath!
            self.buildTopologyFromFile()
        }
        self.service = self.serviceFromSetup(self.setup)
        
        self.initialWindow.contentViewController = self.storyboard.instantiateControllerWithIdentifier(ObserverViewController.STORYBOARD_ID) as? NSViewController
        
        self.instantiateTopology(self.topology, ownPeerName: self.setup.peerName!, topologyFilePath: topologyFilePath, withServiceOfType: self.setup.service)
        
    }
    
    
    func setupAsNode() {
        if self.setup.peerName == nil {
            print("Missing parameter --peerName")
            exit(2)
        }
        if self.setup.peerName == OBSERVER_NAME {
            print("Invalid value for parameter --peerName:")
            print("'\(OBSERVER_NAME)' is prohibited as a node name")
        }
        self.setupLogger()
        
        self.buildTopologyFromFile()
        
        self.service = self.serviceFromSetup(self.setup)

        self.initialWindow.contentViewController = self.storyboard.instantiateControllerWithIdentifier(NodeViewController.STORYBOARD_ID) as? NSViewController

        self.layoutWindow(CGSizeMake(350, 150), margin: 20)
    }
    
    
    // MARK: Topology
    
    
    /**
    
     Erstellt eine AVATopology-Instanz aus dem Setup.
    
     */
    func buildTopologyFromFile() {
        if let path = self.setup.topologyFilePath {
            do {
                self.topology = try AVATopology(jsonPath: path)
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
            do {
                self.topology = try AVATopology(randomWithDimension: dimension)
            } catch {
                
            }
        } else {
            print("Missing parameter --randomTopologySize")
            exit(2)
        }
    }
    
    
    // MARK: | Termination
    
    private var terminated = false
    
    /**
     
     Sendet eine Terminate-Message an alle Nachbarn und beendet den Prozess mit einer Verzögerung von 1 Sekunde.
     
     */
    func terminateTopologyIfNecessary() {
        if !self.terminated {
            self.terminated = true
            self.nodeManager?.broadcastMessage(AVAMessage.terminateMessage(self.setup.peerName!))
            if !self.setup.isObserver {
                self.nodeManager?.close()
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                    exit(0)
                }
            }
        }
    }
    

    // MARK: Instantiation
    
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
        task.arguments = [
            TOPOLOGY_PARAMETER_NAME, topology,
            PEER_NAME_PARAMETER_NAME, vertex.name
        ]
        
        if self.setup.logDebug {
            task.arguments?.append(LOG_DEBUG_NAME)
        }
        if self.setup.logInfo {
            task.arguments?.append(LOG_INFO_NAME)
        }
        if self.setup.logWarning {
            task.arguments?.append(LOG_WARNING_NAME)
        }
        if self.setup.logError {
            task.arguments?.append(LOG_ERROR_NAME)
        }
        if self.setup.logSuccess {
            task.arguments?.append(LOG_SUCCESS_NAME)
        }
        if self.setup.logMeasurement {
            task.arguments?.append(LOG_MEASUREMENT_NAME)
        }
        if self.setup.logLifecycle {
            task.arguments?.append(LOG_LIFECYCLE_NAME)
        }
        if self.setup.disableNodeUILog {
            task.arguments?.append(DISABLE_NODE_UI_LOG_NAME)
        }
        if self.setup.instantMeasurement {
            task.arguments?.append(INSTANT_MEASUREMENT_NAME)
        }
        task.arguments?.appendContentsOf(serviceType.nodeInstantiationParametersFromSetup(self.setup))
        dispatch_async(dispatch_queue_create("peer_\(vertex)_instantiate", DISPATCH_QUEUE_SERIAL)) { () -> Void in
            task.launch()
        }
        self.log(AVALogEntry(level: AVALogLevel.Lifecycle, event: AVAEvent.Processing, peer: self.setup.peerName!, description: "Instantiated peer '\(vertex.name)'", remotePeer: vertex.name))
    }
    
    
    // MARK: Layout
    
    
    /**
    
     Positioniert das Fenster der Anwendung so, dass es schoen aussieht.
    
     */
    func layoutWindow(size: CGSize, margin: CGFloat) {
        if let window = NSApplication.sharedApplication().windows.first {
            let visibleScreenFrame = window.screen?.visibleFrame
            let windowesPerRow = UInt(floor((visibleScreenFrame?.size.width)! / (size.width + margin)))
            
            let topology = self.topology.topologyExcludingObserver()
            let verticesSorted = topology.vertices.sort({ (a: AVAVertex, b: AVAVertex) -> Bool in
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
    
    
    // MARK: | Service Startup
    
    
    func handleStandbyMessage(message: AVAMessage) {
        let logEntry: AVALogEntry
        if self.setup.isObserver {
            self.topology.vertextForName(message.sender)?.hasRepotedStandby = true
            logEntry = AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup.peerName, description: "Node '\(message.sender)' reported standby. (\(self.topology.verticesInStandby().count)/\(self.topology.vertices.count - 1))", remotePeer: message.sender, message: message)
            if self.topology.verticesInStandby().count == self.topology.vertices.count - 1 {
                print("Topology is ready to start")
                self.log(AVALogEntry(level: AVALogLevel.Lifecycle, event: AVAEvent.Processing, peer: OBSERVER_NAME, description: "Topology is ready to start"))
            }
        } else {
            logEntry = AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Processing, peer: self.setup.peerName, description: "Received Standby message from '\(message.sender)'", remotePeer: message.sender, message: message)
            
        }
        self.log(logEntry)
    }
    
    
    func handleInitializationMessage(message: AVAMessage) {
        if !self.setup.isObserver {
            self.service?.start()
        } else {
            let logEntry = AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Processing, peer: self.setup.peerName, description: "Received Initialization message from '\(message.sender)'", remotePeer: message.sender, message: message)
            self.log(logEntry)
        }
    }
    
    
    func startServiceIfNecessary() {
        if !self.setup.isObserver {
            if let service = self.service {
                if !service.isRunning {
                    let logEntry = AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup.peerName, description: "Node '\(self.setup.peerName)' is now providing the configured service")
                    self.log(logEntry)
                    service.initializeWithBufferedMessage(self.messageBuffer)
                }
            }
        }
    }
    
    
    // MARK: | Termination
    
    var terminationCheckingQueue: dispatch_queue_t = dispatch_queue_create("", DISPATCH_QUEUE_SERIAL)
    
    
    func scheduleTerminationCheck() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), self.terminationCheckingQueue) { () -> Void in
            self.initializeTerminationChecking()
        }
    }
    
    
    func initializeTerminationChecking() {
        var peers = [AVAVertexName]()
        for vertex in self.topology.vertices {
            if vertex.name != OBSERVER_NAME {
                peers.append(vertex.name)
                vertex.messageReceivedCount = nil
                vertex.messageSentCount = nil
            }
        }
        self.nodeManager?.sendMessage(AVAMessage.terminationStatusRequestMessage(OBSERVER_NAME), toVertices: peers)
    }
    
    
    var lastOverallMessagReceivedCount: UInt?
    
    
    var lastOverallMessagSentCount: UInt?
    
    
    func receivedMessageCountFromAllNodes() -> Bool {
        for vertex in self.topology.vertices {
            if vertex.name != OBSERVER_NAME {
                if vertex.messageSentCount == nil || vertex.messageReceivedCount == nil {
                    return false
                }
            }
        }
        return true
    }
    
    
    func handleTerminationStatusMessage(message: AVAMessage) {
        if let vertex = self.topology.vertextForName(message.sender), let payload = message.payload {
            do {
                let status = try AVATerminationStatus(json: payload)
                vertex.messageSentCount = status.sentCount
                vertex.messageReceivedCount = status.receivedCount
            } catch {
                
            }
        }
    }
    
    
    func checkForTermination() -> Bool {
        var sent: UInt = 0
        var received: UInt = 0
        
        for vertex in self.topology.vertices {
            if vertex.name != OBSERVER_NAME {
                sent += vertex.messageSentCount!
                received += vertex.messageReceivedCount!
            }
        }
        if let lastSent = self.lastOverallMessagSentCount, let lastReceived = self.lastOverallMessagReceivedCount {
            if lastSent == sent && lastReceived == received {
                return true
            }
        }
        self.lastOverallMessagSentCount = sent
        self.lastOverallMessagReceivedCount = received
        return false
    }
    
    
    func sendOwnTerminationStatus() {
        let status = self.nodeManager?.terminationStatus
        self.nodeManager?.sendMessage(AVAMessage(type: AVAMessageType.TerminationStatus, sender: self.setup.peerName, payload: status?.toJSON()), toVertex: OBSERVER_NAME)
    }
    
    
    // MARK: | Measurements
    
    func requestMeasurementsIfNecessary() {
        if let service = self.service {
            if service.needsMeasurement {
                let message = AVAMessage.finalMeasurementRequestMessage(OBSERVER_NAME)
                self.nodeManager?.broadcastMessage(message)
            }
        }
    }
}


/**
 
 Implementiert das AVALogging Protokoll.
 
 */
extension AppDelegate: AVALogging {
    
    func log(entry: AVALogEntry) {
        switch (entry.level) {
        case .Debug:
            if !self.setup.logDebug {
                return
            }
            break
            
        case .Info:
            if !self.setup.logInfo {
                return
            }
            break
            
        case .Warning:
            if !self.setup.logWarning {
                return
            }
            break
            
        case .Error:
            if !self.setup.logError {
                return
            }
            break
            
        case .Success:
            if !self.setup.logSuccess {
                return
            }
            break
            
        case .Measurement:
            if !self.setup.logMeasurement {
                return
            }
            break
            
        case .Lifecycle:
            if !self.setup.logLifecycle {
                return
            }
            break
        }
        dispatch_async(self.loggingQueue) { () -> Void in
            if let stream = self.loggingStream, log = entry.jsonStringValue() {
                stream.write("\(log),\n")
            }
        }
        if !self.setup.disableNodeUILog {
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                let attributedString = NSAttributedString(string: "[\(entry.event.stringValue())]: \(entry.entryDescription)\n", attributes: entry.level.attributes())
                self.loggingTextView?.textStorage?.appendAttributedString(attributedString)
                self.loggingTextView?.scrollRangeToVisible(NSMakeRange((self.loggingTextView?.string?.characters.count)!, 0))
            }
            
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
            if self.setup.isObserver {
                
            } else {
                self.startServiceIfNecessary()
                nodeManager.sendMessage(AVAMessage.standbyMessage(self.setup.peerName), toVertex: OBSERVER_NAME)
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
            self.terminateTopologyIfNecessary()
            break
            
        case .Standby:
            self.handleStandbyMessage(message)
            break
            
        case .Initialize:
            self.handleInitializationMessage(message)
            break;
            
        case .ApplicationData:
            if self.service!.isRunning {
                self.service!.nodeManager(nodeManager, didReceiveApplicationDataMessage: message)
            } else {
                self.messageBuffer.append(message)
            }
            break
            
        case .TerminationStatusRequest:
            self.sendOwnTerminationStatus()
            break
            
        case .TerminationStatus:
            self.handleTerminationStatusMessage(message)
            if self.receivedMessageCountFromAllNodes() {
                if self.checkForTermination() {
                    self.log(AVALogEntry(level: AVALogLevel.Lifecycle, event: AVAEvent.Termination, peer: self.setup.peerName!, description: "Service has terminated"))
                    self.requestMeasurementsIfNecessary()
                } else {
                    self.scheduleTerminationCheck()
                }
            }
            break
            
        case .FinalMeasurementRequest:
            let message = AVAMessage(type: AVAMessageType.FinalMeasurement, sender: self.setup.peerName, payload: self.service!.finalMeasurements)
            self.service!.onFinalMeasurementSent()
            self.nodeManager?.sendMessage(message, toVertex: OBSERVER_NAME)
            break
            
        case .FinalMeasurement:
            self.service!.handleMeasurementMessage(message)
            break;
        }
    }
    

    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData) {
        
    }
}


extension AppDelegate {
    
    /**
     
     Erstellt den entsprechenden Service aus dem Setup.
     
     - parameters:
        - setup: Das AVASetup, welches aus den Uebergabe-Parametern erstellt wurde.
     
     - returns: Den entsprechenden AVAService.
     
     */
    func serviceFromSetup(setup: AVASetup) -> AVAService {
        switch setup.service! {
        case AVAServiceType.Uebung1:
            return AVAUebung1(setup: setup)
            
        case AVAServiceType.Uebung2:
            return AVAUebung2(setup: setup)
            
        case AVAServiceType.Uebung3:
            return AVAUebung3(setup: setup)
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