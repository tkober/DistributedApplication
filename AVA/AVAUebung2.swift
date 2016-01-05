//
//  AVAUebung2.swift
//  AVA
//
//  Created by Thorsten Kober on 27.12.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVAUebung2: NSObject, AVAService {
    
    private let FINAL_MEASUREMENT_BALANCE_KEY = "balance"
    private let FINAL_MEASUREMENT_LEADER_STRATEGY_KEY = "leaderStrategy"
    private let FINAL_MEASUREMENT_FOLLOWER_STRATEGY_KEY = "followerStrategy"
    
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
                if let number = attributes.valueForKey(LEADER_STRATEGY_ATTRIBUTE)?.integerValue {
                    return number
                }
            }
            return nil
        }
    }
    
    private var followerStrategy: AVAFollowerStrategy? {
        get {
            if let attributes = (self.nodeAttributes as? NSDictionary) {
                if let number = attributes.valueForKey(FOLLOWER_STRATEGY_ATTRIBUTE)?.integerValue {
                    return number
                }
            }
            return nil
        }
    }
    
    private var balance: Double = 0
    
    private var halt = false {
        didSet {
            if self.setup!.instantMeasurement {
                if self.halt == true {
                    let message = AVAMessage(type: AVAMessageType.FinalMeasurement, sender: self.setup!.peerName!, payload: self.finalMeasurements)
                    self.onFinalMeasurementSent()
                    self.nodeManager.sendMessage(message, toVertex: OBSERVER_NAME)
                }
            }
        }
    }
    
    
    // MARK: | Instance Handling
    
    private func handleReceivedInstance(instance: AVALeaderFollowerInstance, fromPeer peer: AVAVertexName) {
        if instance.result != nil {
            // Leader
            if !self.halt {
                self.handleResultOfInstance(instance, follower: peer)
                if let maxBalance = self.setup?.maxBalance {
                    if self.balance > maxBalance {
                        self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Node '\(self.setup!.peerName!)' reached maximum balance \(maxBalance)(\(self.balance)) and will HALT"))
                        self.halt = true
                        return
                    }
                }
                if instance.halt {
                    self.halt = true
                    self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Received result with HALT flag from '\(peer)' and will HALT too", remotePeer: peer))
                }
            }
        } else {
            // Follower
            if self.halt {
                // Halt already set
                self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Declined offer from '\(peer)' and sending HALT", remotePeer: peer))
                instance.result = AVALeaderFollowerInstanceResult.Declined
                instance.halt = true
                self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertex: peer)
                return
            }
            // Halt not yet set
            if let followerStrategy = self.followerStrategy {
                
                // Follower strategy exists
                if self.shouldAcceptInstance(instance, followerStrategy: followerStrategy) {
                    // Accepting offer
                    self.applyStrategyOnFollower(instance.leaderStrategy, withStake: self.setup!.stake!)
                    self.logger.log(AVALogEntry(level: AVALogLevel.Success, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Accepted offer from '\(peer)', balance -> \(self.balance)", remotePeer: peer))
                    if let maxBalance = self.setup?.maxBalance {
                        if self.balance > maxBalance {
                            self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Node '\(self.setup!.peerName!)' reached maximum balance \(maxBalance)(\(self.balance)) and will HALT"))
                            instance.halt = true
                            self.halt = true
                        }
                    }
                } else {
                    // Declining offer
                    self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Declined offer from '\(peer)'", remotePeer: peer))
                }
                self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertex: peer)
                
                if !self.halt {
                    if let leaderStrategy = self.leaderStrategy {
                        self.createInstances(self.setup!.nodesToContactCount!, withLeaderStrategy: leaderStrategy)
                    }
                }
            } else {
                // Follower Strategy missing
                instance.result = AVALeaderFollowerInstanceResult.NoFollowerStrategy
                self.logger.log(AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Declining proposal from peer '\(peer)' due to missing follower strategy", remotePeer: peer))
                self.nodeManager.sendMessage(AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: instance.toJSON()), toVertex: peer)
                if !self.halt {
                    if let leaderStrategy = self.leaderStrategy {
                        self.createInstances(self.setup!.nodesToContactCount!, withLeaderStrategy: leaderStrategy)
                    }
                }
            }
        }
    }
    
    
    private func shouldAcceptInstance(instance: AVALeaderFollowerInstance, followerStrategy strategy: AVAFollowerStrategy) -> Bool {
        if instance.leaderStrategy >= strategy {
            instance.result = AVALeaderFollowerInstanceResult.Accepted
            return true
        } else {
            instance.result = AVALeaderFollowerInstanceResult.Declined
            return false
        }
    }
    
    
    private func applyStrategyOnLeader(strategy: AVALeaderStrategy, withStake stake: Double) {
        self.balance += stake - Double(strategy)

    }

    
    
    private func applyStrategyOnFollower(strategy: AVALeaderStrategy, withStake stake: Double) {
        self.balance += Double(strategy)
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
    
    
    var needsMeasurement = true
    
    
    var finalMeasurements: AVAJSON! {
        get {
            var result = [
                FINAL_MEASUREMENT_BALANCE_KEY: NSNumber(double: self.balance)
            ]
            if let leaderStrategy = self.leaderStrategy {
                result[FINAL_MEASUREMENT_LEADER_STRATEGY_KEY] = NSNumber(integer: leaderStrategy)
            }
            if let followerStrategy = self.followerStrategy {
                result[FINAL_MEASUREMENT_FOLLOWER_STRATEGY_KEY] = NSNumber(integer: followerStrategy)
            }
            return result
        }
    }
    
    
    func onFinalMeasurementSent() {
        self.logger.log(AVALogEntry(level: AVALogLevel.Measurement, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Final balance of node '\(self.setup!.peerName!)' is \(self.balance)"))
    }
    
    
    func handleMeasurementMessage(message: AVAMessage) {
        let appDelegate = NSApp.delegate as! AppDelegate
        if let vertex = appDelegate.topology.vertextForName(message.sender) {
            vertex.measurements = message.payload
        }
        
        var measurements = [AVALeaderFollowerMeasurement]()
        for vertex in appDelegate.topology.vertices {
            if vertex.name != OBSERVER_NAME {
                if vertex.measurements == nil {
                    return
                }
                let measurement = vertex.measurements as! NSDictionary
                measurements.append(AVALeaderFollowerMeasurement(name: vertex.name, balance: measurement[FINAL_MEASUREMENT_BALANCE_KEY] as! NSNumber, leaderStrategy: measurement[FINAL_MEASUREMENT_LEADER_STRATEGY_KEY] as? NSNumber, followerStrategy: measurement[FINAL_MEASUREMENT_FOLLOWER_STRATEGY_KEY] as? NSNumber))
            }
        }
        measurements.sortInPlace { (a: AVALeaderFollowerMeasurement, b: AVALeaderFollowerMeasurement) -> Bool in
            return a.balance.doubleValue > b.balance.doubleValue
        }
        var csv = "node (Strategies);Balance"
        for measurement in measurements {
            csv += "\n"
            csv += measurement.csvValue()
        }
        self.logger.log(AVALogEntry(level: AVALogLevel.Measurement, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Game result as CSV:\n\(csv)"))
    }
}


struct AVALeaderFollowerMeasurement {
    
    var name: AVAVertexName
    
    var balance: NSNumber
    
    var leaderStrategy: NSNumber?
    
    var followerStrategy: NSNumber?
    
    
    func csvValue() -> String {
        // name (LS|FS);Balance
        return "\(self.name)(\(self.leaderStrategy != nil ? self.leaderStrategy!.stringValue : "-")|\(self.followerStrategy != nil ? self.followerStrategy!.stringValue : "-"));\(self.balance)"
    }
}

