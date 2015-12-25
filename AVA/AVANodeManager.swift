//
//  AVAServiceManager.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation
import MultipeerConnectivity


typealias AVABroadcastResult = [AVAVertexName: Bool]


/**
 
 Repräsentiert den Status des eigenen Knoten, sprich welche Nachbarn bereits verbunden sind.
 
 */
struct AVANodeState {
    
    /**
     
     Der Name des eigenen Knoten.
     
     */
    let ownVertexName: AVAVertexName
    
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
     
        - ownVertexName: Der Name des eigenen Knoten.
     
        - session: Die Session des eigenen Knoten.
     
     */
    init(topology: AVATopology, ownVertexName: AVAVertexName, streams: [AVASocketStream]) {
        self.ownVertexName = ownVertexName
        self.topology = topology
        var connected = [AVAVertexName]()
        var disconnected = [AVAVertexName]()
        for stream in streams {
            if stream.connected {
                connected.append(stream.vertex.name)
            } else {
                disconnected.append(stream.vertex.name)
            }
        }
        self.connectedPeers = connected
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
     
     */
    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData)
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
    private let verticesToConnect: [AVAVertex]
    
    
    private var vertexNamesToConnect: [AVAVertexName] {
        get {
            var result = [AVAVertexName]()
            for vertex in self.verticesToConnect {
                result.append(vertex.name)
            }
            return result
        }
    }
    
    
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
        self.verticesToConnect = topology.adjacentVerticesForVertex(ownPeerName)
        self.ownVertex = self.topology.vertextForName(ownPeerName)!
        self.serverSocket = AVAServerSocket(vertex: ownVertex)
        
        super.init()
        self.serverSocket.delegate = self
    }
    
    
    var serverSocket: AVAServerSocket
    
    
    var socketStreams = [AVASocketStream]()
    
    
    /**
     
     Startet den AVANodeManager.
     
     */
    func start() {
        serverSocket.setup()
        serverSocket.start()
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            for vertex in self.verticesToConnect {
                let vertexName = self.topology.vertextForName(vertex.name)!
                let socketStream = AVASocketStream(vertex: vertexName)
                socketStream.delegate = self
                self.socketStreams.append(socketStream)
                socketStream.open()
            }
        }
    }
    
    
    // MARK: | State
    
    
    /**
    
    Der aktuelle Status des AVANodeManagers
    
    */
    var state: AVANodeState? {
        get {
            return AVANodeState(topology: self.topology, ownVertexName: self.ownVertex.name, streams: self.socketStreams)
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
        for stream in self.socketStreams {
            if stream.vertex.name == vertex {
                if let messageData = message.jsonData() {
                    let result = stream.writeData(messageData)
                    let logEntry: AVALogEntry
                    if result {
                        logEntry = AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.DataSent, peer: self.ownVertex.name, description: "Sent message (\(message.size) bytes) to '\(vertex)'", remotePeer: vertex, message: message)
                    } else {
                        logEntry = AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.DataSent, peer: self.ownVertex.name, description: "Failed to send message (\(message.size) bytes) to '\(vertex)'", remotePeer: vertex, message: message)
                    }
                    self.logger.log(logEntry)
                    return result
                } else {
                    return false
                }
            }
        }
        return false
    }
    
    
    /**
     
     Sendet eine Nachricht an eine Liste von Knoten.
    
     - parameters:
     
        - message: Die Nachtricht die gesendet werden soll.
     
        - vertices: Die Knoten, an welche die Nachricht gesendet werden soll.
     
     - returns: Einen AVABroadcastResult, welches angibt ob das Senden erfolgreich war.
     
     */
    func sendMessage(message: AVAMessage, toVertices vertices: [AVAVertexName]) -> AVABroadcastResult {
        var result = AVABroadcastResult()
        for vertex in vertices {
            if vertex != OBSERVER_NAME {
                result[vertex] = self.sendMessage(message, toVertex: vertex)
            }
        }
        return result
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn.
     
     - parameters: 
     
        - message: Die Nachtricht die gesendet werden soll.
     
     - returns: Einen AVABroadcastResult, welches angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage) -> AVABroadcastResult {
        return self.sendMessage(message, toVertices: self.vertexNamesToConnect)
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn, mit Ausnahme einer Liste an Knoten.
     
     - parameters:
     
        - message: Die Nachtricht die gesendet werden soll.
     
        - exceptingVertices: Die Knoten, an welche die Nachricht nicht gesendet werden soll.
     
     - returns: Einen AVABroadcastResult, welches angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage, exceptingVertices: [AVAVertexName]) -> AVABroadcastResult {
        var receivers = [AVAVertexName]()
        for vertex in self.vertexNamesToConnect {
            if !exceptingVertices.contains(vertex) {
                receivers.append(vertex)
            }
        }
        return self.sendMessage(message, toVertices: receivers)
    }
}



extension AVANodeManager: AVAServerSocketDelegate {
    
    func serverSocket(socket: AVAServerSocket, acceptedConnection connection: AVASocketConnectionInfo) {
        let logEntry = AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.Processing, peer: self.ownVertex.name, description: "Accepted connection from \(connection.address):\(connection.port)")
        self.logger.log(logEntry)
    }
    
    
    func serverSocket(socket: AVAServerSocket, readData data: NSData) {
        do {
            let message = try AVAMessage(data: data)
            let logEntry = AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.DataReceived, peer: self.ownVertex.name, description: "Received message (\(data.length) bytes) from '\(message.sender)' ", remotePeer: message.sender, message: message)
            self.logger.log(logEntry)
            self.delegate?.nodeManager(self, didReceiveMessage: message)
        } catch {
            let logEntry = AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.DataReceived, peer: self.ownVertex.name, description: "Received uninterpretable data (\(data.length) bytes)")
            self.logger.log(logEntry)
            self.delegate?.nodeManager(self, didReceiveUninterpretableData: data)
        }
    }
    
}


extension AVANodeManager: AVASocketStreamDelegate {
    
    
    func socketStreamDidConnection(stream: AVASocketStream) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.Connect, peer: self.ownVertex.name, description: "Connected vertex '\(stream.vertex.name)'", remotePeer: stream.vertex.name))
    }
    
    
    func socketStreamIsReadyToSend(stream: AVASocketStream) {
        self.delegate?.nodeManager(self, stateUpdated: self.state!)
    }
    
    
    func socketStreamDidDisconnect(stream: AVASocketStream) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Disconnect, peer: self.ownVertex.name, description: "Lost connection to vertex '\(stream.vertex.name)'", remotePeer: stream.vertex.name))
        self.delegate?.nodeManager(self, stateUpdated: self.state!)
    }
    
    
    func socketStreamFailed(stream: AVASocketStream, status: NSStreamStatus, error: NSError?) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Processing, peer: self.ownVertex.name, description: "Error occurred in stream to vertex '\(stream.vertex.name)'. error -> '\(error)'", remotePeer: stream.vertex.name))
    }
}



