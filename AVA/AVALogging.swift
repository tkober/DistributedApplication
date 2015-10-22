//
//  AVALogging.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


enum AVALogLevel: Int {
    case Debug;
    case Info;
    case Warning;
    case Error;
}


enum AVAEvent: Int {
    case Discovery;
    case InvitationSent;
    case InvitationReceived;
    case Connecting;
    case Connect;
    case Disconnect;
    case DataSent;
    case DataReceived;
    case Processing;
    
    func stringValue() -> String {
        switch self {
        case .Discovery:
            return "Discovery"
            
        case .InvitationSent:
            return "InvitationSent"
            
        case .InvitationReceived:
            return "InvitationReceived"
            
        case .Connecting:
            return "Connecting"
            
        case .Connect:
            return "Connect"
            
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
}


struct AVALogEntry {
    
    let LEVEL_KEY: NSString = "level"
    let EVENT_KEY: NSString = "event"
    let PEER_NAME_KEY: NSString = "peerName"
    let MESSAGE_KEY: NSString = "message"
    
    let level: AVALogLevel
    let event: AVAEvent
    let peerName: String
    let message: String
    
    
    init(level: AVALogLevel, event: AVAEvent, peerName: String, message: String) {
        self.level = level
        self.event = event
        self.peerName = peerName
        self.message = message
    }
    
    
    func stringValue() -> String? {
        let json: [NSString: AnyObject] = [
            LEVEL_KEY: NSNumber(integer: self.level.rawValue),
            EVENT_KEY: NSNumber(integer: self.event.rawValue),
            PEER_NAME_KEY: self.peerName,
            MESSAGE_KEY: self.message
        ]
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions(rawValue: 0))
            return String(data: jsonData, encoding: NSUTF8StringEncoding)
        } catch {
            return nil
        }
    }
}


protocol AVALogging: class {
    func log(enty: AVALogEntry)
}