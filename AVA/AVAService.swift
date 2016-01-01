//
//  AVAApplication.swift
//  AVA
//
//  Created by Thorsten Kober on 25.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


/**
 
 Dieses Protokoll muss von einer Klasse implementiert werden, die zur Steureung der Logik eines Knoten verwendet werden soll.
 
 */
protocol AVAService: class {
    
    /**
     
     Wird aufgerufen, sobald alle Nachbarn vebunden sind.
     
     - parameters: 
        
        - messages: Die Messages, die empfangen wurden, bevor alle Nachbarn verbunden wurden. Die Orndung entspricht der Reihenfolge des Eintreffenes.
     
     */
    func initializeWithBufferedMessage(messages: [AVAMessage])
    
    
    /**
     
     Wird aufgerufen, wenn der Knoten eine Nachricht vom Typ AVAMessageType.ApplicationData erhalten hat.
     
     - parameters:
        
        - nodeManager: Der AVANodeManager der die Nachricht erhalten hat.
     
        - message: Die erhaltene AVAMessage.
     
     */
    func nodeManager(nodeManager: AVANodeManager, didReceiveApplicationDataMessage message: AVAMessage)
    
    
    /**
     
     Erstellt eine neue Instanz aus mit den Informationen aus dem gegebenen Setup.
     
     - parameters:
     
        - setup: Das AVASetup aus den Übergabe-Parametern.
     
     */
    init(setup: AVASetup)
    
    
    /**
     
     Gibt an ob der Service aktuell ausgeführt wird
     
     */
    var isRunning: Bool { get }
    
    
    /**
     
     Wird auf dem Knoten aufgerufen, der mit der Bearbeitung der eigentlichen Anwendung beginnen soll.
     
     - important: Diese Methode darf auf maximal einem Knoten aufgerufen werden.
     
     */
    func start()
    
    
    /**
     
     Gibt an ob nach der Terminierung des Services Messewerte gesammelt werden sollen.
     
     */
    var needsMeasurement: Bool { get }
    
    
    var finalMeasurements: AVAJSON! { get }

    
    func onFinalMeasurementSent()
    
    
    func handleMeasurementMessage(message: AVAMessage)
}


enum AVAJSONError: ErrorType {
    
    /**
     
     Zeigt an, dass im JSON nicht alle Informationen vorhanden sind um eine Instanz zu erstellen.
     
     */
    case invalidPayload
}


/**
 
 Dieses Protokoll muss von Klassen implementiert werden, die als über AVAMessages im Netzwerk verbreitet weden, bzw. Empfangen werden sollen.
 
 */
protocol AVAJSONConvertable {
    
    /**
     
     Initialisierer zum Erstellen einer Instanz aus JSON.
     
     - important: Falls das JSON nicht alle erforderlichen Werte enthält sollte eine Exception geworfen werden.
     
     */
    init(json: AVAJSON) throws
    
    
    /**
     
     Erzeugt JSON aus dem aktuellen Zustand der Instanz.
     
     - returns: JSON, aus welchem sich der aktuelle Zustand der Instanz wiederherstellen lassen sollte.
     
     */
    func toJSON() -> AVAJSON
    
}