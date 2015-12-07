//
//  AVAServiceManager.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation
import MultipeerConnectivity


/**
 
 Repräsentiert den Status des eigenen Knoten, sprich welche Nachbarn bereits verbunden sind.
 
 */
struct AVANodeState {
    
    /**
     
     Der Name des eigenen Knoten.
     
     */
    let ownPeer: AVAVertexName
    
    /**
     
     Die Topologie.
     
     */
    let topology: AVATopology
    
    /**
     
     Die Nachbarn, die bereits verbunden sind.
     
     */
    let connectedPeers: [AVAVertexName]
    
    /**
     
     Die Nachbar, die noch nicht verbunden sind.
     
     */
    let disconnectedPeers: [AVAVertexName]
    
    
    /**
     
     Erzeugt den Status für eine gegebene Topologie.
     
     - parameters:
     
        - topology: Die Topologie, für welche ein Status erzeugt werden soll.
     
        - ownPeer: Der Name des eigenen Knoten.
     
        - session: Die Session des eigenen Knoten.
     
     */
    init(topology: AVATopology, ownPeer: AVAVertexName, session: MCSession) {
        self.ownPeer = ownPeer
        self.topology = topology
        
        var connected = [AVAVertexName]()
        for peer in session.connectedPeers {
            connected.append(peer.displayName)
        }
        self.connectedPeers = connected
        
        var disconnected = [AVAVertexName]()
        for vertex in topology.adjacentVerticesForVertex(ownPeer) {
            if !self.connectedPeers.contains(vertex) {
                disconnected.append(vertex)
            }
        }
        self.disconnectedPeers = disconnected
    }
}



/**
 
 Dieses Protokoll muss von Klassen implementiert werde, die als Delegate eines AVANodeManagers fungieren sollen.
 
 */
protocol AVANodeManagerDelegate {
    
    /**
     
     Wird aufgerufen, wenn sich der Status eines AVANodeManagers ändert.
     
     - parameters:
     
        - nodeManager: Der AVANodeManager, dessen Status sich geändert hat.
     
        - state: Der neue Status.
     
     */
    func nodeManager(nodeManager: AVANodeManager, stateUpdated state: AVANodeState)
    
    /**
     
     Wird aufgerufen, wenn ein AVANodeManager, eine Nachricht empfangen hat.
     
     - parameters:
     
        - nodeManager: Der AVANodeManager, der eine Nachricht empfangen hat.
     
        - message: Die Empfangene Nachricht.
     
     */
    func nodeManager(nodeManager: AVANodeManager, didReceiveMessage message: AVAMessage)
    
    /**
     
     Wird aufgerufen, wenn ein AVANodeManager Daten erhalten hat, aus denen sich keine AVAMesage instantiieren ließ.
     
     - parameters:
     
        - nodeManager: Der AVANodeManager, die Daten empfangen hat.
     
        - data: Die empfangenen Daten.
     
        - peer: Der Absender der Daten.
     
     */
    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData, fromPeer peer: AVAVertexName)
}



/**
 
 Ist für die gesamte Netzwerkkommunikation zwischen eines Knotens und seinen Nachbarn zuständig.
 
 */
class AVANodeManager: NSObject {
 
    /**
     
     Die Topologie, in welcher sich der Knoten befindet.
     
     */
    let topology: AVATopology
    
    /**
     
     Die Socket Konfiguration des eigenen Knotens aus der Topologie.
     
     */
    let ownVertex: AVAVertex
    
    /**
     
     Ein Liste mit den Namen der Nachbarn, also den Peers die verbunden werden sollen.
     
     */
    private let peersToConnect: [AVAVertexName]
    
    /**
     
     Der delegate des NodeManagers.
     
     */
    var delegate: AVANodeManagerDelegate?
    
    /**
     
     Der Logger, welchem
     
     */
    var logger: AVALogging

    
    /**
     
     Erzeugt einen neuen AVANodeManger, der als ein gegebener Knoten in einer gegeben Topologie arbeitet.
     
     - parameters:
     
        - topology: Die Topologie, in welcher gearbetiet werden soll.
     
        - ownPeerName: Der Name des eigenen Knotens.
     
        - logger: Der Logger der verwendet werden soll.
     
     */
    init(topology: AVATopology, ownPeerName: String, logger: AVALogging) {
        self.topology = topology
        self.logger = logger
        self.peersToConnect = topology.adjacentVerticesForVertex(ownPeerName)
        self.ownVertex = self.topology.vertextForName(ownPeerName)!
        self.serverSocket = AVAServerSocket(vertex: ownVertex)
        
        super.init()
        self.serverSocket.delegate = self
    }
    
    
    var serverSocket: AVAServerSocket
    
    
    /**
     
     Startet den AVANodeManager.
     
     */
    func start() {
        serverSocket.setup()
        serverSocket.start()
    }
    
    
    // MARK: | State
    
    
    /**
    
    Der aktuelle Status des AVANodeManagers
    
    */
    var state: AVANodeState? {
        get {
            // TODO: Implement
            return nil
        }
    }
    
    
    // MARK: | Messaging
    
    
    /**
    
     Sendet eine AVAMessage an einen Knoten.
    
     - parameters:
    
       - message: Die Nachtricht die gesendet werden soll.
    
       - vertex: Der Knoten, an welchen die Nachricht gesendet werden soll.
    
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
    
    */
    func sendMessage(message:AVAMessage, toVertex vertex: AVAVertexName) -> Bool {
//        for connectedPeer in self.session.connectedPeers {
//            if connectedPeer.displayName == vertex {
//                return self.sendMessage(message, toPeers: [connectedPeer])
//            }
//        }
        // TODO: Implement
        return false
    }
    
    
    /**
     
     Sendet eine Nachricht an eine Liste von Knoten.
    
     - parameters:
     
        - message: Die Nachtricht die gesendet werden soll.
     
        - peers: Die Knoten, an welche die Nachricht gesendet werden soll.
     
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
     
     */
    func sendMessage(message: AVAMessage, toPeers peers: [MCPeerID]) -> Bool {
//        for peer in peers {
//            if !self.session.connectedPeers.contains(peer) {
//                return false
//            }
//        }
//        if let messageData = message.jsonData() {
//            do {
//                try self.session.sendData(messageData, toPeers: peers, withMode: MCSessionSendDataMode.Unreliable)
//                for peer in peers {
//                    self.logger.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.DataSent, peer: self.myPeerId.displayName, description: "Sent message (\(messageData.length) bytes) to \(peer.displayName)", remotePeer: peer.displayName, message: message))
//                }
//                return true
//            } catch {
//                return false
//            }
//        } else {
//            return false
//        }
        // TODO: Implement
        return false
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn.
     
     - parameters: 
     
        - message: Die Nachtricht die gesendet werden soll.
     
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage) -> Bool {
//        return self.sendMessage(message, toPeers: self.session.connectedPeers)
        // TODO: Implement
        return false
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn, mit Ausnahme einer Liste an Knoten.
     
     - parameters:
     
        - message: Die Nachtricht die gesendet werden soll.
     
        - exceptingPeers: Die Knoten, an welche die Nachricht nicht gesendet werden soll.
     
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage, exceptingPeers: [MCPeerID]) -> Bool {
//        var peers = [MCPeerID]()
//        for peer in self.session.connectedPeers {
//            if !exceptingPeers.contains(peer) {
//                peers.append(peer)
//            }
//        }
//        return self.sendMessage(message, toPeers: peers)
        // TODO: Implement
        return false
    }
    

    
    
    
    private var inputStream: NSInputStream!
    private var outputStream: NSOutputStream!
    
    
    func test() {
        
        var readStream:  Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, "localhost", 5000, &readStream, &writeStream)
        
        
        self.inputStream = readStream!.takeRetainedValue()
        self.outputStream = writeStream!.takeRetainedValue()
        
        self.inputStream.delegate = self
        self.outputStream.delegate = self
        
        self.inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.outputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.inputStream.open()
            self.outputStream.open()
        }
    }
 
    
    var helloWorldSent = false
}



extension AVANodeManager: AVASocketDelegate {
    
}



extension AVANodeManager: NSStreamDelegate {
    
    
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        let status = aStream.streamStatus
//        print("aStream -> \(aStream) status -> \(status) eventCode -> \(eventCode.stringValue())")
        
        if eventCode == NSStreamEvent.HasSpaceAvailable {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                let stream = aStream as! NSOutputStream
                stream.write("Hello from \(self.ownVertex.name)")
            }
        }
    }
}




