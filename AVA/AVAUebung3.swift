//
//  AVAUebung3.swift
//  AVA
//
//  Created by Thorsten Kober on 05.01.16.
//  Copyright © 2016 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVAUebung3: NSObject, AVAService {
    
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
    
    
    private static let INITIAL_SHARED_RESOURCE_CONTENT = "000000000"
    
    
    private func scheduleMutexEntrance() {
        self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Node '\(self.setup!.peerName!)' scheduled mutex entrance"))
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
                let mutexAction = try AVAMutexAction(json: payload)
                switch mutexAction.type {
                    
                case .Start:
                    self.scheduleMutexEntrance()
                    break
                    
                case .Request:
                    break
                    
                case .Confirmation:
                    break
                    
                case .Release:
                    break
                    
                }
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
        
        if setup.isObserver {
            if let path = self.setup?.sharedResoucePath {
                do {
                    if NSFileManager.defaultManager().fileExistsAtPath(path) {
                        try NSFileManager.defaultManager().removeItemAtPath(path)
                    }
                    try AVAUebung3.INITIAL_SHARED_RESOURCE_CONTENT.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
                } catch {
                    print("Fatal Error: Setting up shared resource failed.")
                    exit(7);
                }
            } else {
                print("Missing parameter: --sharedResource")
                exit(5);
            }
        }
    }
    
    
    func start() {
        let startMessage = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: AVAMutexAction(type: AVAMutexActionType.Start).toJSON())
        self.nodeManager.broadcastMessage(startMessage, exceptingVertices: [OBSERVER_NAME])
        self.scheduleMutexEntrance()
    }
    
    
    var isRunning = false
    
    
    var needsMeasurement = true
    
    
    var finalMeasurements: AVAJSON! {
        get {
            return nil
        }
    }
    
    
    func onFinalMeasurementSent() {
    }
    
    
    func handleMeasurementMessage(message: AVAMessage) {

    }
}