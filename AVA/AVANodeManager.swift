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
     
     Das eigene Peer.
     
     */
    let myPeerId: MCPeerID
    
    
    /**
     
     Der Name des Bonjour-Service mit dem Advertising betrieben wird.
     
     */
    private let AVA_SERVICE_TYPE = "ava"
    
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    
    /**
     
     Ein Liste mit den Namen der Nachbarn, also den Peers die verbunden werden sollen.
     
     */
    private let peersToConnect: [AVAVertexName]
    
    /**
     
     Die MCSessions-Objekte der Nachbarn mit denen der eigene Knoten verbunden ist.
     
     */
    private var remoteSessions = [AVAVertexName: MCSession]()
    
    
    /**
     
     Die eigene MCSession mit der sich die Nachbarn verbinden sollen.
     
     */
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
        session.delegate = self
        return session
    }()
    
    
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
        self.myPeerId = MCPeerID(displayName: ownPeerName)
        self.peersToConnect = topology.adjacentVerticesForVertex(ownPeerName)
        
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: AVA_SERVICE_TYPE)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: AVA_SERVICE_TYPE)
        
        super.init()
    }
    
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    
    
    /**
     
     Startet den AVANodeManager.
     
     */
    func start() {
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    
    // MARK: | State
    
    
    /**
    
    Der aktuelle Status des AVANodeManagers
    
    */
    var state: AVANodeState {
        get {
            return AVANodeState(topology: self.topology, ownPeer: self.myPeerId.displayName, session: session)
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
        for connectedPeer in self.session.connectedPeers {
            if connectedPeer.displayName == vertex {
                return self.sendMessage(message, toPeers: [connectedPeer])
            }
        }
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
        for peer in peers {
            if !self.session.connectedPeers.contains(peer) {
                return false
            }
        }
        if let messageData = message.jsonData() {
            do {
                try self.session.sendData(messageData, toPeers: peers, withMode: MCSessionSendDataMode.Unreliable)
                for peer in peers {
                    self.logger.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.DataSent, peer: self.myPeerId.displayName, description: "Sent message (\(messageData.length) bytes) to \(peer.displayName)", remotePeer: peer.displayName, message: message))
                }
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn.
     
     - parameters: 
     
        - message: Die Nachtricht die gesendet werden soll.
     
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage) -> Bool {
        return self.sendMessage(message, toPeers: self.session.connectedPeers)
    }
    
    
    /**
     
     Sendet eine Nachricht an alle Nachbarn, mit Ausnahme einer Liste an Knoten.
     
     - parameters:
     
        - message: Die Nachtricht die gesendet werden soll.
     
        - exceptingPeers: Die Knoten, an welche die Nachricht nicht gesendet werden soll.
     
     - returns: Einen boolschen Wert, der angibt ob das Senden erfolgreich war.
     
     */
    func broadcastMessage(message: AVAMessage, exceptingPeers: [MCPeerID]) -> Bool {
        var peers = [MCPeerID]()
        for peer in self.session.connectedPeers {
            if !exceptingPeers.contains(peer) {
                peers.append(peer)
            }
        }
        return self.sendMessage(message, toPeers: peers)
    }
    
}


extension AVANodeManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        print("\(__FUNCTION__)")
        print("error -> \(error)")
    }
    
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: ((Bool, MCSession) -> Void)) {
        let logEntry = AVALogEntry(level: .Debug, event: .InvitationReceived, peer: self.myPeerId.displayName, description: "Received Invitation from peer \(peerID.displayName)", remotePeer: peerID.displayName)
        self.logger.log(logEntry)
        if (self.peersToConnect.contains(peerID.displayName)) {
            let session = MCSession(peer: self.myPeerId)
            session.delegate = self
            self.remoteSessions[peerID.displayName] = session
            invitationHandler(true, session)
        }
    }
    
}


extension AVANodeManager : MCNearbyServiceBrowserDelegate {
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        print("\(__FUNCTION__)")
        print("error -> \(error)")
    }
    
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let logEntry = AVALogEntry(level: .Debug, event: .Discovery, peer: self.myPeerId.displayName, description: "Discovered peer \(peerID.displayName)", remotePeer: peerID.displayName)
        self.logger.log(logEntry)
        if self.peersToConnect.contains(peerID.displayName) {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 20)
        }
    }
    
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
}


extension AVANodeManager : MCSessionDelegate {
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        if session != self.session {
            return
        }
        
        let event: AVAEvent
        let level: AVALogLevel
        switch (state) {
        case .Connecting:
            event = AVAEvent.Connecting
            level = AVALogLevel.Debug
            break;
            
        case .Connected:
            event = AVAEvent.Connect
            level = AVALogLevel.Info
            break;
            
        case .NotConnected:
            event = AVAEvent.Disconnect
            level = AVALogLevel.Error
            break;
        }
        
        let logEntry = AVALogEntry(level: level, event: event, peer: self.myPeerId.displayName, description: "Peer '\(peerID.displayName)' changed status to \(state.stringValue())", remotePeer: peerID.displayName)
        self.logger.log(logEntry)
        self.delegate?.nodeManager(self, stateUpdated: self.state)
    }
    
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        do {
            let message = try AVAMessage(data: data)
            let logEntry = AVALogEntry(level: .Info, event: .DataReceived, peer: self.myPeerId.displayName, description: "Received message (\(data.length) bytes) from \(peerID.displayName)", remotePeer: peerID.displayName, message: message)
            self.logger.log(logEntry)
            self.delegate?.nodeManager(self, didReceiveMessage: message)
        } catch {
            let logEntry = AVALogEntry(level: .Warning, event: .DataReceived, peer: self.myPeerId.displayName, description: "Received uninterpretable data (\(data.length) bytes) from \(peerID.displayName)", remotePeer: peerID.displayName)
            self.logger.log(logEntry)
            self.delegate?.nodeManager(self, didReceiveUninterpretableData: data, fromPeer: peerID.displayName)
        }
    }
    
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("\(__FUNCTION__)")
    }
    
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        print("\(__FUNCTION__)")
    }
    
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        print("\(__FUNCTION__)")
    }
}


extension MCSessionState {
    
    func stringValue() -> String {
        switch(self) {
        case .NotConnected:
            return "NotConnected"
            
        case .Connecting:
            return "Connecting"
            
        case .Connected:
            return "Connected"
        }
    }
    
}