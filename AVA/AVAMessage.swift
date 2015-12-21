//
//  AVAMessage.swift
//  AVA
//
//  Created by Thorsten Kober on 24.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


typealias AVAJSON = AnyObject


/**
 
 Enthält die Arten einer Nachricht.
 
 */
enum AVAMessageType: Int {
    
    /**
     
     Die Nachricht soll an alle Nachbarn weitergeleitet werden und danach soll der Prozess terminiert werden.
     
     */
    case Terminate = 0;
    
    
    /**
     
     Die Nachricht enthält Daten die für den Service des Knoten bestimmt sind.
     
     */
    case ApplicationData;
}



/**
 
 Repräsentiert eine Nachricht, die in der Topologie verbeitet werden kann.
 
 */
class AVAMessage: NSObject {
    
    private static let TYPE_JSON_KEY = "type"
    private static let TIMESTAMP_JSON_KEY = "timestamp"
    private static let SENDER_JSON_KEY = "sender"
    private static let PAYLOAD_JSON_KEY = "payload"
    
    
    /**
     
     Der Typ der Nachricht.
     
     */
    let type: AVAMessageType
    
    
    /**
     
     Der Zeitpunkt, zu welchem Die Nachricht gesendet wurde.
     
     */
    let timestamp: NSTimeInterval
    
    
    /**
     
     Der Absender der Nachricht.
     
     */
    let sender: AVAVertexName
    
    
    /**
     
     Übermittelter Payload als JSON.
     
     */
    var payload: AVAJSON?
    
    
    var size: Int {
        get {
            if let data = self.jsonData() {
                return data.length
            } else {
                return 0
            }
        }
    }
    
    
    // MARK: | Initializer
    
    
    /**
    
     Erstellt eine neue Nachricht.
    
     - parameters:
    
       - type: Der Typ der Nachricht.
    
       - sender: Der Absender der Nachricht.
    
       - payload: Eventueller Payload als JSON. Default-Wert ist nil.
    
       - timestamp: Der Timestamp der Nachricht. Default-Wert ist die Aktuelle Zeit.
    
     */
    init(type: AVAMessageType, sender: String, payload: AVAJSON? = nil, timestamp: NSTimeInterval = NSDate().timeIntervalSince1970) {
        self.type = type
        self.sender = sender
        self.payload = payload
        self.timestamp = timestamp
    }
    
    
    /**
     
     Erzeugt eine neue Nachricht aus einem gegebenen JSON-Objekt.
     
     - parameters:
     
        - json: Das JSON-Objekt, aus welchem die Nachricht erstellt werden soll.
     
     */
    convenience init(json: [String: AnyObject]) {
        let type = json[AVAMessage.TYPE_JSON_KEY] as! NSNumber
        let sender = json[AVAMessage.SENDER_JSON_KEY]
        let payload = json[AVAMessage.PAYLOAD_JSON_KEY]
        let timestamp = (json[AVAMessage.TIMESTAMP_JSON_KEY] as! NSNumber).doubleValue
        self.init(type: AVAMessageType(rawValue: type.integerValue)!, sender: (sender as! String), payload: payload, timestamp: timestamp)
    }
    
    
    /**
     
     Erzeugt eine neue Nachricht aus einem JSON-Objekt.
     
     - parameters:
     
       - data: Das JSON-Objekt, aus welchem die Nachricht erstellt werden soll als NSData.
     
     - important: Falls die gegebenen Daten kein JSON-Objekt repräsentieren wird eine Exception geworfen.
     
     */
    convenience init(data: NSData) throws {
        let json: [String: AnyObject]
        try json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) as! [String: AnyObject]
        self.init(json: json)
    }
    
    
    /**
     
     Erzeugt eine Terminate-Message für einen gegeben Sender.
     
     - parameters: 
     
        - sender: Der Absender der Nachricht.
     
     - returns: Die erzeugte Nachricht.
     
     */
    static func terminateMessage(sender: String) -> AVAMessage {
        return AVAMessage(type: AVAMessageType.Terminate, sender: sender)
    }
    
    
    /**
     
     Erzeugt eine neue Nachricht mit Daten von/für den Service der Knoten.
     
     - parameters:
     
        - sender: Der Absender der Nachricht.
     
        - payload: Eventueller Payload der gesendet werden soll.
     
     - returns: Die erzeugte Nachricht.
     
     */
    static func applicationDataMessage(sender: String, payload: AnyObject) -> AVAMessage {
        return AVAMessage(type: AVAMessageType.ApplicationData, sender: sender, payload: payload)
    }
    
    
    // MARK: | JSON
    
    
    /**
    
     Erzeugt JSON, mit dessen Hilfe die Nachricht reinstanziiert werden kann.
    
     - returns: Das entsprechende JSON-Objekt.
    
     */
    func json() -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            AVAMessage.TYPE_JSON_KEY: NSNumber(integer: self.type.rawValue),
            AVAMessage.TIMESTAMP_JSON_KEY: NSNumber(double: self.timestamp),
            AVAMessage.SENDER_JSON_KEY: self.sender,
        ]
        if let payload = self.payload {
            result[AVAMessage.PAYLOAD_JSON_KEY] = payload
        }
        return result
    }
    
    
    /**
     
     Erzeugt JSON, mit dessen Hilfe die Nachricht reinstanziiert werden kann, als String.
     
     - returns: Das entsprechende JSON-Objekt als String.
     
     */
    func stringValue() -> String? {
        var result: String?
        if let jsonData = self.jsonData() {
            result = String(data: jsonData, encoding: NSUTF8StringEncoding)
        }
        return result
    }
    
    
    /**
     
     Erzeugt JSON, mit dessen Hilfe die Nachricht reinstanziiert werden kann, als NSData-Objekt.
     
     - returns: Das entsprechende JSON-Objekt als NSData-Objekt.
     
     */
    func jsonData() -> NSData? {
        let json = self.json()
        do {
            let data: NSData?
            try data = NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
            return data
        } catch {
            return nil
        }
    }
}