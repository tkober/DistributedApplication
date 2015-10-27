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
    
    private let LEVEL_KEY: String = "level"
    private let EVENT_KEY: String = "event"
    private let PEER_KEY: String = "peer"
    private let DESCRIPTION_KEY: String = "description"
    private let REMOTE_KEY: String = "remotePeer"
    private let MESSAGE_KEY: String = "message"
    
    let level: AVALogLevel
    let event: AVAEvent
    let peer: String
    let description: String
    let remotePeer: String?
    let message: AVAMessage?
    
    
    init(level: AVALogLevel, event: AVAEvent, peer: String, description: String, remotePeer: String? = nil, message: AVAMessage? = nil) {
        self.level = level
        self.event = event
        self.peer = peer
        self.description = description
        self.remotePeer = remotePeer
        self.message = message
    }
    
    
    func stringValue() -> String? {
        var json: [String: AnyObject] = [
            LEVEL_KEY: NSNumber(integer: self.level.rawValue),
            EVENT_KEY: NSNumber(integer: self.event.rawValue),
            PEER_KEY: self.peer,
            DESCRIPTION_KEY: self.description
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


protocol AVALogging: class {
    func log(enty: AVALogEntry)
}