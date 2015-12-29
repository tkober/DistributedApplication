//
//  AVALogging.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


/**
 
 Enthält die Verschiedenen Log-Ebenen.
 
 */
enum AVALogLevel: Int {
    case Debug;
    case Info;
    case Warning;
    case Error;
    case Success;
    case Measurement;
    
    
    func stringValue() -> String {
        switch (self) {
        case .Debug:
            return "Debug"
            
        case .Info:
            return "Info"
            
        case .Warning:
            return "Warning"
            
        case .Error:
            return "Error"
            
        case .Success:
            return "Success"
            
        case .Measurement:
            return "Measurement"
        }
    }
    
    
    func attributes() -> [String: AnyObject] {
        var attributes: [String: AnyObject]
        switch (self) {
        case .Debug:
            attributes = [NSForegroundColorAttributeName: NSColor.darkGrayColor()]
            break
            
        case .Info:
            attributes = [NSForegroundColorAttributeName: NSColor.blueColor()]
            break
            
        case .Warning:
            attributes = [NSForegroundColorAttributeName: NSColor.orangeColor()]
            break
            
        case .Error:
            attributes = [NSForegroundColorAttributeName: NSColor.redColor()]
            break
            
        case .Success:
            attributes = [NSForegroundColorAttributeName: NSColor.purpleColor()]
            break
            
        case .Measurement:
            attributes = [NSForegroundColorAttributeName: NSColor.greenColor()]
            break
        }
        return attributes
    }
    
    
    func graphvizsColor() -> AVAGraphvizColor {
        switch (self) {
        case .Debug:
            return AVAGraphvizBlack
            
        case .Info:
            return AVAGraphvizBlue
            
        case .Warning:
            return AVAGraphvizOrange
            
        case .Error:
            return AVAGraphvizRed
            
        case .Success:
            return AVAGraphvizPurple
            
        case .Measurement:
            return AVAGraphvizGreen
        }
    }
}



/**
 
 Beschreibt die Ereignisse, die einen Log-Eintrag hervorrufen.
 
 */
enum AVAEvent: Int {
    case AcceptedConnection
    case Connect
    case ConnectionError
    case Disconnect
    case DataSent
    case DataReceived
    case Processing
    
    
    func stringValue() -> String {
        switch self {
        
        case .AcceptedConnection:
            return "AcceptedConnection"
            
        case .Connect:
            return "Connect"
            
        case .ConnectionError:
            return "ConnectionError"
            
        case .Disconnect:
            return "Disconnect"
            
        case .DataSent:
            return "DataSent"
            
        case .DataReceived:
            return "DataReceived"
            
        case .Processing:
            return "Processing"
            
        }
    }
    
    
    func adjacencyDirection(ownPeerToRemoteInOrder inOrder: Bool) -> AVAGraphvizAdjacencyDirection {
        switch self {
            
        case .AcceptedConnection:
            return inOrder ? .InOrder : .Inverse
            
        case .Connect:
            return inOrder ? .InOrder : .Inverse
            
        case .ConnectionError:
            return inOrder ? .InOrder : .Inverse
            
        case .Disconnect:
            return inOrder ? .InOrder : .Inverse
            
        case .DataSent:
            return inOrder ? .InOrder : .Inverse
            
        case .DataReceived:
            return inOrder ? .Inverse : .InOrder
            
        default:
            return .Undirected
            
        }
    }
}


private let LEVEL_KEY: String = "level"
private let EVENT_KEY: String = "event"
private let PEER_KEY: String = "peer"
private let DESCRIPTION_KEY: String = "description"
private let REMOTE_KEY: String = "remotePeer"
private let MESSAGE_KEY: String = "message"
private let TIMESTAMP_KEY: String = "timestamp"


/**
 
 Beschreibt einen Log-Eintrag.
 
 */
class AVALogEntry: NSObject {
    
    /**
     
     Die Log-Ebene des Eintrags.
     
     */
    let level: AVALogLevel
    
    
    /**
     
     Das auslösende Ereignis.
     
     */
    let event: AVAEvent
    
    
    /**
     
     Der Knoten auf welchem dieses Ereignis eintrat.
     
     */
    let peer: String
    
    
    /**
     
     Eine kurze Beschreibung.
     
     */
    let entryDescription: String
    
    
    /**
     
     Der Nachbar auf welchen sich das auslösende Ereignis eventuell bezieht.
     
     */
    let remotePeer: String?
    
    /**
     
     Eine eventuell übermittelte Nachricht.
     
     */
    let message: AVAMessage?
    
    
    /**
     
     Ein Timestamp.
     
     */
    let timestamp: NSTimeInterval
    
    
    /**
     
     Erstellt einen neuen Log-Eintrag.
     
     - parameters:
     
        - level: Der AVALogLevel des Eintrags.
    
        - event: Das auslösende Ereignis.
     
        - peer: Der Knoten auf welchem dieses Ereignis eintrat.
     
        - description: Eine kurze Beschreibung.
     
        - remotePeer: Der Nachbar auf welchen sich das auslösende Ereignis eventuell bezieht. Der Default-Wert ist nil.
     
        - message: Eine eventuell übermittelte Nachricht. Der Default-Wert ist nil.
     
        - timestamp: Der Zeitpunkt, zu welchem das Ereignis auftrat. Der Default wert ist die aktuelle Zeit.
     
     */
    init(level: AVALogLevel, event: AVAEvent, peer: String, description: String, remotePeer: AVAVertexName? = nil, message: AVAMessage? = nil, timestamp: NSTimeInterval = NSDate().timeIntervalSince1970) {
        self.level = level
        self.event = event
        self.peer = peer
        self.entryDescription = description
        self.remotePeer = remotePeer
        self.message = message
        self.timestamp = timestamp
    }
    
    
    /**
     
     Erstellt einen neuen Log-Eintrag aus gegebenem JSON.
     
     - parameters:
     
        - json: Ein JSON-Objekt welches die Informationen eines Log-Eintrags enthält.
     
     */
    convenience init(json: [String: AnyObject]) {
        let logLevel = AVALogLevel(rawValue: (json[LEVEL_KEY] as! NSNumber).integerValue)!
        let event = AVAEvent(rawValue: (json[EVENT_KEY] as! NSNumber).integerValue)!
        let peer = json[PEER_KEY] as! String
        let entryDescription = json[DESCRIPTION_KEY] as! String
        let remotePeer = json[REMOTE_KEY] as! String?
        var message: AVAMessage?
        if let messageJSON = json[MESSAGE_KEY] as! [String: AnyObject]? {
            message = AVAMessage(json: messageJSON)
        }
        let timestamp = (json[TIMESTAMP_KEY] as! NSNumber).doubleValue
        self.init(level: logLevel, event: event, peer: peer, description: entryDescription, remotePeer: remotePeer, message: message, timestamp: timestamp)
    }
    
    
    /**
     
     Erzeugt JSON als String, aus welchem sich der Zustand einer Instanz reinstanziieren lässt.
     
     - returns: Ein entsprechendes JSON-Objekt als String.
     
     */
    func jsonStringValue() -> String? {
        var json: [String: AnyObject] = [
            LEVEL_KEY: NSNumber(integer: self.level.rawValue),
            EVENT_KEY: NSNumber(integer: self.event.rawValue),
            PEER_KEY: self.peer,
            DESCRIPTION_KEY: self.entryDescription,
            TIMESTAMP_KEY: NSNumber(double: self.timestamp)
        ]
        if let remotePeer = self.remotePeer {
            json[REMOTE_KEY] = remotePeer
        }
        if let messageJSON = self.message?.json() {
            json[MESSAGE_KEY] = messageJSON
        }
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions(rawValue: 1))
            return String(data: jsonData, encoding: NSUTF8StringEncoding)
        } catch {
            return nil
        }
    }
}


/**
 
 Dieses Protokoll muss von einer Klasse implementiert werden, um AVALogEnty-Objekte verarbeiten zu können.
 
 */
protocol AVALogging: class {
    
    
    /**
     
     Wird zur Verarbeitung eines Log-Eintrags aufgerufen.
     
     
     - parameters:
        
        - entry: Der Log-Eintrag, der verarbeitet werden soll.
     
     */
    func log(enty: AVALogEntry)
    
    
    /**
     
     Wird aufgerufen um den Logger zu starten.
     
     */
    func setupLogger()
}


/**
 
 > Operator, welcher prüft ob ein Log-Eintrag zeitlich nach einem anderen liegt.
 
 */
func >(lhs: AVALogEntry, rhs: AVALogEntry) -> Bool {
    return lhs.timestamp > rhs.timestamp
}


/**
 
 < Operator, welcher prüft ob ein Log-Eintrag zeitlich vor einem anderen liegt.
 
 */
func <(lhs: AVALogEntry, rhs: AVALogEntry) -> Bool {
    return lhs.timestamp < rhs.timestamp
}