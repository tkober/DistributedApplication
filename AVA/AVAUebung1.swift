//
//  AVAUebung1.swift
//  AVA
//
//  Created by Thorsten Kober on 28.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


/**
 
 Implementiert die Logik der Übung 1.
 
 Beim Starten des Services werden die gebufferten Nachrichten nach der Reihenfolge ihres Eintreffens über die nodeManager:didReceiveApplicationDataMessage: Methode aus dem AVAService Protokoll verarbeitet.
 
 Sollte der Knoten beim Start der Master seinm, sendet er das Gerüht aus dem Setup an seine Nachbarn.
 
 */
class AVAUebung1: NSObject, AVAService {
    
    
    /**
     
     Alle Empfangenen Gerüchte
     
     */
    private var rumors = [AVARumor]()
    
    
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
    
    
    /**
     
     Verarbeitet ein eingetroffenes Gerücht wie folgt:
     
        1. Falls in der Liste der bereits gehörten Gerüchte ein gleiches Objekt enthalten ist, wird der Sender der Liste heardFrom hinzugefüt, falls diese den Sendern nicht bereits enthält. Wurde das Gerücht noch nicht gehört wird es der Liste der gehörten Gerüchte hinzugefügt.
     
        2. Falls das Gerücht von ausreichend Knoten gehöhrt wurde, wird es markiert.
     
    - parameters:
        
        - rumor: Das gehörte Gerücht.
     
        - peer: Der Sender, vom welchem das Gerücht gehört wurde.
     
     */
    func handleHeardRumor(rumor: AVARumor, fromPeer peer: AVAVertexName) {
        let rumorIndex = self.rumors.indexOf { (item: AVARumor) -> Bool in
            return item == rumor
        }
        var heardRumor = rumor
        if let index = rumorIndex {
            heardRumor = self.rumors[index]
            // Nicht Weitersagen
            if !heardRumor.heardFrom.contains(peer) {
                heardRumor.heardFrom.append(peer)
            }
        } else {
            rumor.heardFrom.append(peer)
            self.rumors.append(rumor)
            // Weitersagen
            let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: rumor.toJSON())
            self.nodeManager.broadcastMessage(message, exceptingVertices: [peer])
        }
        if heardRumor.heardFrom.count >= self.setup?.rumorCountToAcceptance! && !heardRumor.accepted {
            self.logger.log(AVALogEntry(level: AVALogLevel.Success, event: AVAEvent.Processing, peer: self.setup!.peerName!, description: "Peer '\(self.setup!.peerName!)' accepted rumor '\(rumor.rumorText)'"))
            heardRumor.accepted = true
        }
    }
    
    
    // MARK: | AVAService
    
    
    required init(setup: AVASetup) {
        self.setup = setup
        self.logger = NSApp.delegate as! AppDelegate
        super.init()
    }
    
    
    func initializeWithBufferedMessage(messages: [AVAMessage]) {
        self.isRunning = true
        for message in messages {
            self.nodeManager(self.nodeManager, didReceiveApplicationDataMessage: message)
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
    
    
    func start() {
        let rumor = AVARumor(rumor: self.setup!.rumor!)
        self.logger.log(AVALogEntry(level: AVALogLevel.Warning, event: AVAEvent.Processing, peer: self.setup!.peerName! , description: "Start spreading rumor '\(self.setup!.rumor!)'"))
        let message = AVAMessage(type: AVAMessageType.ApplicationData, sender: self.setup!.peerName!, payload: rumor.toJSON())
        self.nodeManager.broadcastMessage(message)
    }
    
    
    var isRunning = false
}
