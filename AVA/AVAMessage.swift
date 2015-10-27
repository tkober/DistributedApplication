//
//  AVAMessage.swift
//  AVA
//
//  Created by Thorsten Kober on 24.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


typealias AVAJSON = AnyObject


enum AVAMessageType: Int {
    case Terminate = 0;
    case ApplicationData;
}


class AVAMessage: NSObject {
    
    private static let TYPE_JSON_KEY = "type"
    private static let TIMESTAMP_JSON_KEY = "timestamp"
    private static let SENDER_JSON_KEY = "sender"
    private static let PAYLOAD_JSON_KEY = "payload"
    
    
    let type: AVAMessageType
    let timestamp: NSDate
    let sender: String
    var payload: AVAJSON?
    
    
    // MARK: | Initializer
    
    
    init(type: AVAMessageType, sender: String, payload: AVAJSON? = nil, timestamp: NSDate = NSDate()) {
        self.type = type
        self.sender = sender
        self.payload = payload
        self.timestamp = timestamp
    }
    
    
    static func terminateMessage(sender: String) -> AVAMessage {
        return AVAMessage(type: AVAMessageType.Terminate, sender: sender)
    }
    
    
    static func applicationDataMessage(sender: String, payload: AnyObject) -> AVAMessage {
        return AVAMessage(type: AVAMessageType.ApplicationData, sender: sender, payload: payload)
    }
    
    
    static func messageFromData(data: NSData) -> AVAMessage? {
        let json: [String: AnyObject]
        do {
            try json = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) as! [String: AnyObject]
            if let type = json[AVAMessage.TYPE_JSON_KEY], sender = json[AVAMessage.SENDER_JSON_KEY], timestampString = json[AVAMessage.TIMESTAMP_JSON_KEY] {
                let payload = json[AVAMessage.PAYLOAD_JSON_KEY]
                let timestamp = NSDate.dateFromISO8601Representation(timestampString as! String)
                return AVAMessage(type: AVAMessageType(rawValue: (type as! NSNumber).integerValue)!, sender: (sender as! String), payload: payload, timestamp: timestamp!)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    
    // MARK: | JSON
    
    
    func json() -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            AVAMessage.TYPE_JSON_KEY: NSNumber(integer: self.type.rawValue),
            AVAMessage.TIMESTAMP_JSON_KEY: self.timestamp.iso8601Representation(),
            AVAMessage.SENDER_JSON_KEY: self.sender,
        ]
        if let payload = self.payload {
            result[AVAMessage.PAYLOAD_JSON_KEY] = payload
        }
        return result
    }
    
    
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