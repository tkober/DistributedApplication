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
    
    
    private var criticalSectionEntranceTimer: NSTimer!
    
    
    private func scheduleCriticalSectionEntranceIfNeeded() {
        if self.needsAdditionalCriticalSecionEntrance() {
            let delay = (Double(arc4random_uniform(500))) / Double(1000)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                self.requestCriticalSectionEntrance()
            }
            
//            dispatch_sync(dispatch_get_main_queue()) { () -> Void in
//                self.criticalSectionEntranceTimer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: "requestCriticalSectionEntrance", userInfo: nil, repeats: false)
//            }

        }
    }
    
    
    func requestCriticalSectionEntrance() {
        let lamportTimestamp = LAMPORT_CLOCK.tick()
        let entrance = AVACriticalSectionEntranceRequest(node: self.setup!.peerName!, timestamp: NSDate().timeIntervalSince1970, lamportTimestamp: lamportTimestamp)
        let appDelegate = NSApp.delegate as! AppDelegate
        for vertex in appDelegate.topology.topologyExcludingObserver().vertices {
            if vertex.name != appDelegate.setup.peerName {
                entrance.nodesToConfirm.append(vertex.name)
            }
        }
        self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Node '\(self.setup!.peerName!)' requested criticical section entrance"))
        self.addCriticalSectionEntranceRequestToQueue(entrance)
        let mutexAction = AVAMutexAction(type: AVAMutexActionType.Request, timestamp: entrance.timestamp, lamportTimestamp: entrance.lamportTimestamp)
        let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: mutexAction.toJSON())
        self.nodeManager.broadcastMessage(message, exceptingVertices: [OBSERVER_NAME])
        self.scheduleCriticalSectionEntranceIfNeeded()
    }
    
    
    private var _mutexQueue = [AVACriticalSectionEntranceRequest]()
    
    
    private func addCriticalSectionEntranceRequestToQueue(request: AVACriticalSectionEntranceRequest) {
        self._mutexQueue.append(request)
//        print("\(self.setup!.peerName!) -> \(self.mutexQueue)")
    }
    
    
    private func removeCriticalSectionEntranceRequestFromQueue(request: AVACriticalSectionEntranceRequest) {
        if let index = self._mutexQueue.indexOf(request) {
            self._mutexQueue.removeAtIndex(index)
        }
    }
    
    
    private var mutexQueue: [AVACriticalSectionEntranceRequest] {
        get {
            return self._mutexQueue.sort({ (a: AVACriticalSectionEntranceRequest, b: AVACriticalSectionEntranceRequest) -> Bool in
                return a < b
            })
        }
    }
    
    
    private func handleMutexEntranceRequest(entrance: AVACriticalSectionEntranceRequest) {
        self.addCriticalSectionEntranceRequestToQueue(entrance)
        let action = AVAMutexAction(type: AVAMutexActionType.Confirmation, timestamp: entrance.timestamp, lamportTimestamp: entrance.lamportTimestamp)
        let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName, payload: action.toJSON())
        self.nodeManager.sendMessage(message, toVertex: entrance.node)
    }
    
    
    private func handleMutexConfirmation(mutexAction: AVAMutexAction, fromNode from: AVAVertexName) {
        for mutex in self.mutexQueue {
            if mutex.node == self.setup!.peerName && mutex.lamportTimestamp == mutexAction.lamportTimestamp {
                if let index = mutex.nodesToConfirm.indexOf(from) {
                    mutex.nodesToConfirm.removeAtIndex(index)
                }
                let logEntry = AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName, description: "'\(from)' confirmed critical section entrance request. \(mutex.nodesToConfirm.count) confirmations pending")
                self.logger.log(logEntry)
                return
            }
        }
        print("Critical section entrance request not found \(from)@\(mutexAction.timestamp)")
    }
    
    
    private let ciriticaSectionWorkerQueue = dispatch_queue_create("ava.ciritical_section_worker_queue", DISPATCH_QUEUE_SERIAL)
    
    
    private func scheduleCriticalSectionExecution() {
        dispatch_async(self.ciriticaSectionWorkerQueue) { () -> Void in
            self.executeCriticalSecionIfRequired()
        }
    }
    
    
    private func executeCriticalSecionIfRequired() {
        while true {
            if let nextMutex = self.mutexQueue.first {
                if nextMutex.node == self.setup!.peerName && nextMutex.nodesToConfirm.count == 0 {
                    self.removeCriticalSectionEntranceRequestFromQueue(nextMutex)
                    if self.needsAdditionalCriticalSecionEntrance() {
                        self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName, description: "Entering critical section"))
                        self.useSharedResource()
                        self.logger.log(AVALogEntry(level: AVALogLevel.Success, event: AVAEvent.Processing, peer: self.setup!.peerName, description: "Leaving critical section"))
                    } else {
                        self.logger.log(AVALogEntry(level: AVALogLevel.Lifecycle, event: AVAEvent.Termination, peer: self.setup!.peerName, description: "Process terminated and will not enter the critical section anymore"))
                        let measurementMessage = AVAMessage(type: AVAMessageType.FinalMeasurement, sender: self.setup!.peerName, payload: nil)
                        self.nodeManager.sendMessage(measurementMessage, toVertex: OBSERVER_NAME)
                    }
                    let action = AVAMutexAction(type: AVAMutexActionType.Release, timestamp: nextMutex.timestamp, lamportTimestamp: nextMutex.lamportTimestamp)
                    let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName, payload: action.toJSON())
                    self.nodeManager.broadcastMessage(message, exceptingVertices: [OBSERVER_NAME])
                }
            }
        }
    }
    
    
    private var zeroReadInSharedResourceCounter = 0
    
    
    private func useSharedResource() {
        let sharedResouceConent = String(data: NSData(contentsOfFile: self.setup!.sharedResoucePath!)!, encoding: NSUTF8StringEncoding)
        let sharedResouceRows = sharedResouceConent?.componentsSeparatedByString("\n")
        var sharedResouceValue = Int(sharedResouceRows!.first!)!
        
        if sharedResouceValue == 0 {
            zeroReadInSharedResourceCounter++
        }
        
        if Int(self.setup!.peerName)! % 2 == 0 {
            sharedResouceValue--
        } else {
            sharedResouceValue++
        }
        
        var newContent = "\(sharedResouceValue)"
        for var i = 1; i < sharedResouceRows!.count; i++ {
            newContent += "\n\(sharedResouceRows![i])"
        }
        newContent += "\n\(self.setup!.peerName)"
        do {
            try newContent.writeToFile(self.setup!.sharedResoucePath!, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            let logEntry = AVALogEntry(level: AVALogLevel.Error, event: AVAEvent.Processing, peer: self.setup!.peerName, description: "Error while writing to shared resource")
            self.logger.log(logEntry)
        }
    }
    
    
    private func needsAdditionalCriticalSecionEntrance() -> Bool {
        return self.zeroReadInSharedResourceCounter < 3
    }
    
    
    private func handleMutexRelease(mutexAction: AVAMutexAction, fromNode from: AVAVertexName) {
        for mutex in self.mutexQueue {
            if mutex.node == from && mutex.timestamp == mutexAction.timestamp {
                self.removeCriticalSectionEntranceRequestFromQueue(mutex)
                let logEntry = AVALogEntry(level: AVALogLevel.Info, event: AVAEvent.Processing, peer: self.setup!.peerName, description: "Removed critical section entrance of peer '\(mutex.node)' from queue")
                self.logger.log(logEntry)
                return
            }
        }

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
                    self.scheduleCriticalSectionExecution()
                    self.scheduleCriticalSectionEntranceIfNeeded()
                    break
                    
                case .Request:
                    self.handleMutexEntranceRequest(AVACriticalSectionEntranceRequest(node: message.sender, timestamp: mutexAction.timestamp, lamportTimestamp: mutexAction.lamportTimestamp))
                    break
                    
                case .Confirmation:
                    self.handleMutexConfirmation(mutexAction, fromNode: message.sender)
                    break
                    
                case .Release:
                    self.handleMutexRelease(mutexAction, fromNode: message.sender)
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
        let startMessage = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: AVAMutexAction(type: AVAMutexActionType.Start, timestamp: NSDate().timeIntervalSince1970, lamportTimestamp: LAMPORT_CLOCK.tick()).toJSON())
        self.nodeManager.broadcastMessage(startMessage, exceptingVertices: [OBSERVER_NAME])
        self.scheduleCriticalSectionExecution()
        self.scheduleCriticalSectionEntranceIfNeeded()
    }
    
    
    var isRunning = false
    
    
    var needsMeasurement = false
    
    
    var finalMeasurements: AVAJSON! {
        get {
            return nil
        }
    }
    
    
    func onFinalMeasurementSent() {
    }
    
    
    func handleMeasurementMessage(message: AVAMessage) {
        if self.setup!.isObserver {
            self.logger.log(AVALogEntry(level: AVALogLevel.Lifecycle, event: AVAEvent.Termination, peer: self.setup!.peerName, description: "Node '\(message.sender)' terminated and will not enter the critical section anymore"))
        }
    }
}