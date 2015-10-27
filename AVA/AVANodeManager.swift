//
//  AVAServiceManager.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation
import MultipeerConnectivity


struct AVANodeState {
    let ownPeer: AVAVertex
    let topology: AVATopology
    let connectedPeers: [AVAVertex]
    let disconnectedPeers: [AVAVertex]
    
    init(topology: AVATopology, ownPeer: AVAVertex, session: MCSession) {
        self.ownPeer = ownPeer
        self.topology = topology
        
        var connected = [AVAVertex]()
        for peer in session.connectedPeers {
            connected.append(peer.displayName)
        }
        self.connectedPeers = connected
        
        var disconnected = [AVAVertex]()
        for vertex in topology.adjacentVerticesForVertex(ownPeer) {
            if !self.connectedPeers.contains(vertex) {
                disconnected.append(vertex)
            }
        }
        self.disconnectedPeers = disconnected
    }
}


protocol AVANodeManagerDelegate {
    
    func nodeManager(nodeManager: AVANodeManager, stateUpdated state: AVANodeState)
    func nodeManager(nodeManager: AVANodeManager, didReceiveMessage message: AVAMessage)
    func nodeManager(nodeManager: AVANodeManager, didReceiveUninterpretableData data: NSData, fromPeer peer: AVAVertex)
}


class AVANodeManager: NSObject {
 
    
    private let AVA_SERVICE_TYPE = "ava"
    private let myPeerId: MCPeerID
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    private let topology: AVATopology
    private let peersToConnect: [AVAVertex]
    private var remoteSessions = [AVAVertex: MCSession]()
    
    
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
        session.delegate = self
        return session
    }()
    
    var delegate: AVANodeManagerDelegate?
    var logger: AVALogging

    
    
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
    
    
    func start() {
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    
    // MARK: | State
    
    
    var state: AVANodeState {
        get {
            return AVANodeState(topology: self.topology, ownPeer: self.myPeerId.displayName, session: session)
        }
    }
    
    
    // MARK: | Messaging
    
    
    func sendMessage(message:AVAMessage, toVertex vertex: AVAVertex) -> Bool {
        for connectedPeer in self.session.connectedPeers {
            if connectedPeer.displayName == vertex {
                return self.sendMessage(message, toPeers: [connectedPeer])
            }
        }
        return false
    }
    
    
    func sendMessage(message:AVAMessage, toPeers peers: [MCPeerID]) -> Bool {
        for peer in peers {
            if !self.session.connectedPeers.contains(peer) {
                return false
            }
        }
        if let messageData = message.jsonData() {
            do {
                try self.session.sendData(messageData, toPeers: peers, withMode: MCSessionSendDataMode.Unreliable)
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }
    
    
    func broadcastMessage(message: AVAMessage) -> Bool {
        return self.sendMessage(message, toPeers: self.session.connectedPeers)
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
            level = AVALogLevel.Warning
            break;
        }
        
        let logEntry = AVALogEntry(level: level, event: event, peer: self.myPeerId.displayName, description: "Peer '\(peerID.displayName)' changed status to \(state.stringValue())")
        self.logger.log(logEntry)
        self.delegate?.nodeManager(self, stateUpdated: self.state)
    }
    
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        if let message = AVAMessage.messageFromData(data) {
            let logEntry = AVALogEntry(level: .Info, event: .DataReceived, peer: self.myPeerId.displayName, description: "Received message (\(data.length) bytes) from \(peerID.displayName)", remotePeer: peerID.displayName, message: message)
            self.logger.log(logEntry)
            self.delegate?.nodeManager(self, didReceiveMessage: message)
        } else {
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