//
//  AVAUebung1.swift
//  AVA
//
//  Created by Thorsten Kober on 28.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa
import MultipeerConnectivity


class AVAUebung1: NSObject {
    
    
    private var rumors = [AVARumor]()
    
    
    private let logger: AVALogging
    
    
    private var setup: AVASetup?
    
    
    private lazy var nodeManager: AVANodeManager = {
        let appDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.nodeManager!
    }()
    
    
    init(setup: AVASetup) {
        self.setup = setup
        self.logger = NSApp.delegate as! AppDelegate
        super.init()
    }
    
    
    func handleHeardRumor(rumor: AVARumor, fromPeer peer: AVAVertex) {
        
        let rumorIndex = self.rumors.indexOf { (item: AVARumor) -> Bool in
            return item == rumor
        }
        if let index = rumorIndex {
            let heardRumor = self.rumors[index]
            // Nicht Weitersagen
            if !heardRumor.heardFrom.contains(peer) {
                heardRumor.heardFrom.append(peer)
            }
            
        } else {
            rumor.heardFrom.append(peer)
            self.rumors.append(rumor)
            // Weitersagen
            let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: rumor.toJSON())
            let peerID = self.nodeManager.session.connectedPeers.filter({ (item: MCPeerID) -> Bool in
                return item.displayName == peer
            })
            self.nodeManager.broadcastMessage(message, exceptingPeers: peerID)
        }
    }
    
}


extension AVAUebung1: AVAService {
    
    func startWithBufferedMessage(messages: [AVAMessage]) {
        if self.setup!.isMaster {
            let rumor = AVARumor(rumor: self.setup!.rumor!)
            let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: rumor.toJSON())
            self.nodeManager.broadcastMessage(message)
        } else {
            for message in messages {
                self.nodeManager(self.nodeManager, didReceiveApplicationDataMessage: message)
            }
        }
    }
    
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveApplicationDataMessage message: AVAMessage) {
        if let payload = message.payload {
            do {
                let rumor = try AVARumor(json: payload)
                self.handleHeardRumor(rumor, fromPeer: message.sender)
            } catch AVARumorError.invalidPayload {
                self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Failed to create an AVARumor instance from received application data."))
            } catch {
                
            }
        } else {
            self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Received application data do not contain any payload"))
        }
    }
}