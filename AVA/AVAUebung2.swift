//
//  AVAUebung2.swift
//  AVA
//
//  Created by Thorsten Kober on 27.12.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVAUebung2: NSObject, AVAService {
    
    /**
     
     Der AVALogging, der zum Loggen verwendet werden soll.
     
     */
    private let logger: AVALogging
    
    /**
     
     Das AVASetup welches aus den Übergabe-Parametern erstellt wurde.
     
     */
    private var setup: AVASetup?
    
    /**
     
     Der AVANodeManager des aktuellen Knoten.
     
     */
    private lazy var nodeManager: AVANodeManager = {
        let appDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.nodeManager!
    }()
    
    private var nodeAttributes: AVAJSON? {
        get {
            return self.nodeManager.ownVertex.attributes
        }
    }
    
    private var leaderStrategy: AVALeaderStrategy? {
        get {
            if let attributes = (self.nodeAttributes as? NSDictionary) {
                if let raw = attributes.valueForKey(LEADER_STRATEGY_ATTRIBUTE) {
                    return AVALeaderStrategy(rawValue: (raw as! NSNumber).integerValue)
                }
            }
            return nil
        }
    }
    
    private var followerStrategy: AVAFollowerStrategy? {
        get {
            if let attributes = (self.nodeAttributes as? NSDictionary) {
                if let raw = attributes.valueForKey(FOLLOWER_STRATEGY_ATTRIBUTE) {
                    return AVAFollowerStrategy(rawValue: (raw as! NSNumber).integerValue)
                }
            }
            return nil
        }
    }
    
    private var balance: Double = 0
    
    
    // MARK: | Instance Handling
    
    private func handleReceivedInstance(instance: AVALeaderFollowerInstance, fromPeer peer: AVAVertexName) {
        if instance.result != nil {
            // Leader
            self.handleResultOfInstance(instance, follower: peer)
        } else {
            // Follower
            if let followerStrategy = self.followerStrategy {
                if self.shouldAcceptInstance(instance, followerStrategy: followerStrategy) {
                    self.applyStrategyOnFollower(instance.leaderStrategy, withStake: self.setup!.stake!)
                    self.logger.log(AVALogEntry(level: AVALogLevel.Success, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Accepted offer from '\(peer)', balance -> \(self.balance)", remotePeer: peer))
                } else {
                    self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Declined offer from '\(peer)'", remotePeer: peer))
                }
                self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertex: peer)
                if let leaderStrategy = self.leaderStrategy {
                    self.createInstances(self.setup!.nodesToContactCount!, withLeaderStrategy: leaderStrategy)
                }
            } else {
                instance.result = AVALeaderFollowerInstanceResult.NoFollowerStrategy
                self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Declining proposal from peer '\(peer)' due to missing follower strategy", remotePeer: peer))
                self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertex: peer)
                if let leaderStrategy = self.leaderStrategy {
                    self.createInstances(self.setup!.nodesToContactCount!, withLeaderStrategy: leaderStrategy)
                }
            }
        }
    }
    
    
    private func shouldAcceptInstance(instance: AVALeaderFollowerInstance, followerStrategy strategy: AVAFollowerStrategy) -> Bool {
        switch strategy {
            
        case .AlwaysAccept:
            instance.result = AVALeaderFollowerInstanceResult.Accepted
            return true
            
        case .AcceptAtLeast1Third:
            if instance.leaderStrategy != AVALeaderStrategy.OfferNothing {
                instance.result = AVALeaderFollowerInstanceResult.Accepted
                return true
            }
            break
            
        case .AcceptAtLeast2Third:
            if instance.leaderStrategy == AVALeaderStrategy.OfferEverything || instance.leaderStrategy == AVALeaderStrategy.Offer2Third {
                instance.result = AVALeaderFollowerInstanceResult.Accepted
                return true
            }
            break
            
        case .AcceptEverythingOnly:
            if instance.leaderStrategy == AVALeaderStrategy.OfferEverything {
                instance.result = AVALeaderFollowerInstanceResult.Accepted
                return true
            }
            break
            
        }
        instance.result = AVALeaderFollowerInstanceResult.Declined
        return false
    }
    
    
    private func applyStrategyOnLeader(strategy: AVALeaderStrategy, withStake stake: Double) {
        switch strategy {
            
        case .OfferNothing:
            self.balance += stake
            break
            
        case .Offer1Third:
            self.balance += (stake / 3) * 2;
            break
            
        case .Offer2Third:
            self.balance += stake / 3;
            break
            
        case .OfferEverything:
            break
            
        }
    }

    
    
    private func applyStrategyOnFollower(strategy: AVALeaderStrategy, withStake stake: Double) {
        switch strategy {
            
        case .OfferNothing:
            break
            
        case .Offer1Third:
            self.balance += stake / 3;
            break
            
        case .Offer2Third:
            self.balance += (stake / 3) * 2;
            break
            
        case .OfferEverything:
            self.balance += stake
            break
            
        }
    }
    
    
    private func handleResultOfInstance(instance: AVALeaderFollowerInstance, follower: AVAVertexName) {
        switch instance.result! {
        case .NoFollowerStrategy:
            self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Node '\(follower)' declined offer, due to missing follower strategy", remotePeer: follower))
            break
            
        case .Declined:
            self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Follower '\(follower)' declined offer", remotePeer: follower))
            break
            
        case .Accepted:
            self.applyStrategyOnLeader(instance.leaderStrategy, withStake: self.setup!.stake!)
            self.logger.log(AVALogEntry(level: AVALogLevel.Success, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Follower '\(follower)' accepted offer, balance -> \(self.balance)", remotePeer: follower))
            break
            
        }
    }
    
    
    func createInstances(instanceCount: Int, withLeaderStrategy strategy: AVALeaderStrategy) {
        let instance = AVALeaderFollowerInstance(leaderStrategy: strategy)
        var nodes = self.nodeManager.topology.topologyExcludingObserver().vertices
        var nodesToContact = [AVAVertexName]()
        while nodesToContact.count < instanceCount {
            let i = Int(arc4random_uniform(UInt32(nodes.count)))
            let node = nodes[i].name
            if node != self.setup!.peerName! {
                nodesToContact.append(node)
                nodes.removeAtIndex(i)
            }
        }
        self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertices: nodesToContact)
    }

    
    // MARK: | AVAService
    
    func initializeWithBufferedMessage(messages: [AVAMessage]) {
        self.isRunning = true
        for message in messages {
            self.nodeManager(self.nodeManager, didReceiveApplicationDataMessage: message)
        }
    }
    
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveApplicationDataMessage message: AVAMessage) {
        if let payload = message.payload {
            do {
                let instance = try AVALeaderFollowerInstance(json: payload)
                self.handleReceivedInstance(instance, fromPeer: message.sender)
            } catch AVALeaderFollowerInstanceError.invalidPayload {
                self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Failed to create an AVALeaderFollowerInstanceError instance from received application data."))
            } catch AVALeaderFollowerInstanceError.invalidResultValue {
                self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Failed to create an AVALeaderFollowerInstanceError instance from received application data (invalid result value)."))
            } catch AVALeaderFollowerInstanceError.invalidStrategyValue {
                self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Failed to create an AVALeaderFollowerInstanceError instance from received application data (invalid strategy value)."))
            } catch {
                
            }
        } else {
            self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Received application data do not contain any payload"))
        }
    }
    
    
    required init(setup: AVASetup) {
        let appDelegate = NSApp.delegate as! AppDelegate
        self.setup = setup
        self.logger = appDelegate
        super.init()
        
        if setup.nodesToContactCount! >= appDelegate.topology.topologyExcludingObserver().vertices.count {
            print("Invalid parameter: --nodesToContact must not be greater than or equal to the nodes count.")
            exit(4);
        }
        
        if setup.stake == nil {
            print("Missing parameter: --stake")
            exit(5);
        }
    }
    
    
    func start() {
        if let leaderStrategy = self.leaderStrategy {
            self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName! , description: "Starting the game."))
            self.createInstances(self.setup!.nodesToContactCount!, withLeaderStrategy: leaderStrategy)
        } else {
            self.logger.log(AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Processing, peer: self.setup!.peerName! , description: "Node '\(self.setup!.peerName!)' cannot start the game due to missing leader strategy"))
        }
    }
    
    
    var isRunning = false
}
