//
//  AVALogging.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


enum AVALogLevel: Int {
    case Debug;
    case Info;
    case Warning;
    case Error;
    
    
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
        }
    }
}



enum AVAEvent: Int {
    case Discovery
    case InvitationSent
    case InvitationReceived
    case Connecting
    case Connect
    case Disconnect
    case DataSent
    case DataReceived
    case Processing
    
    
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
    
    
    func adjacencyDirection(ownPeerToRemoteInOrder inOrder: Bool) -> AVAGraphvizAdjacencyDirection {
        switch self {
        case .Discovery:
            return inOrder ? .InOrder : .Inverse
            
        case .InvitationSent:
            return inOrder ? .InOrder : .Inverse
            
        case .InvitationReceived:
            return inOrder ? .Inverse : .InOrder
            
        case .Connecting:
            return inOrder ? .InOrder : .Inverse
            
        case .Connect:
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


class AVALogEntry: NSObject {
    
    let level: AVALogLevel
    let event: AVAEvent
    let peer: String
    let entryDescription: String
    let remotePeer: String?
    let message: AVAMessage?
    let timestamp: NSTimeInterval
    
    
    init(level: AVALogLevel, event: AVAEvent, peer: String, description: String, remotePeer: String? = nil, message: AVAMessage? = nil, timestamp: NSTimeInterval = NSDate().timeIntervalSince1970) {
        self.level = level
        self.event = event
        self.peer = peer
        self.entryDescription = description
        self.remotePeer = remotePeer
        self.message = message
        self.timestamp = timestamp
    }
    
    
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
    
    
    func stringValue() -> String? {
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


protocol AVALogging: class {
    func log(enty: AVALogEntry)
}


func >(lhs: AVALogEntry, rhs: AVALogEntry) -> Bool {
    return lhs.timestamp > rhs.timestamp
}


func <(lhs: AVALogEntry, rhs: AVALogEntry) -> Bool {
    return lhs.timestamp < rhs.timestamp
}