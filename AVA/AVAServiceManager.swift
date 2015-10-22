//
//  AVAServiceManager.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation
import MultipeerConnectivity


typealias AVAMessage = String


protocol AVAServiceManagerDelegate {
    
    func serviceManager(serviceManager: AVAServiceManager, didChangeStateForPeer peer: MCPeerID, inSession session: MCSession)
    func serviceManager(serviceManager: AVAServiceManager, didReceiveMessage message: AVAMessage)
}


class AVAServiceManager: NSObject {
 
    
    private let AVA_SERVICE_TYPE = "ava"
    private let myPeerId: MCPeerID
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    private let peersToConnect: [AVAVertex]
    private var remoteSessions = [AVAVertex: MCSession]()
    
    
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
        session.delegate = self
        return session
    }()
    
    var delegate: AVAServiceManagerDelegate?
    var logger: AVALogging

    
    
    init(topology: AVATopology, ownPeerName: String, logger: AVALogging) {
        self.logger = logger
        self.myPeerId = MCPeerID(displayName: ownPeerName)
        self.peersToConnect = topology.adjacentVerticesForVertex(ownPeerName)
        
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: AVA_SERVICE_TYPE)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: AVA_SERVICE_TYPE)
        
        super.init()
        
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()

        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
}


extension AVAServiceManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        print("\(__FUNCTION__)")
        print("error -> \(error)")
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: ((Bool, MCSession) -> Void)) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.InvitationReceived, peerName: peerID.displayName, message: "Received Invitation from peer \(peerID.displayName)"));
        if (self.peersToConnect.contains(peerID.displayName)) {
            let session = MCSession(peer: self.myPeerId)
            session.delegate = self
            self.remoteSessions[peerID.displayName] = session
            invitationHandler(true, session)
        }
    }
    
}


extension AVAServiceManager : MCNearbyServiceBrowserDelegate {
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        print("\(__FUNCTION__)")
        print("error -> \(error)")
    }
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Debug, event: AVAEvent.Discovery, peerName: peerID.displayName, message: "Discovered peer \(peerID.displayName)"));
        if self.peersToConnect.contains(peerID.displayName) {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 20)
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
}


extension AVAServiceManager : MCSessionDelegate {
    
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
        
        self.logger.log(AVALogEntry(level: level, event: event, peerName: peerID.displayName, message: "Peer '\(peerID.displayName)' changed status to \(state.stringValue())"));
        self.delegate?.serviceManager(self, didChangeStateForPeer: peerID, inSession: self.session)
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.DataReceived, peerName: peerID.displayName, message: "Received \(data.length) bytes from peer \(peerID.displayName)"));
        self.delegate?.serviceManager(self, didReceiveMessage: String(data: data, encoding: NSUTF8StringEncoding)!)
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