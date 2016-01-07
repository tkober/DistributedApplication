//
//  AVAMutexAction.swift
//  AVA
//
//  Created by Thorsten Kober on 05.01.16.
//  Copyright © 2016 Thorsten Kober. All rights reserved.
//

import Cocoa


enum AVAMutexActionType: Int {
    
    case Start = 1
    
    case Request

    case Confirmation
    
    case Release
}


class AVAMutexAction: NSObject, AVAJSONConvertable {
    
    
    private static let TYPE_JSON_KEY = "type"
    
    private static let TIMESTAMP_JSON_KEY = "timestamp"
    
    
    let type: AVAMutexActionType
    
    let timestamp: NSTimeInterval
    
    
    init(type: AVAMutexActionType, timestamp: NSTimeInterval) {
        self.type = type
        self.timestamp = timestamp
    }
    
    
    // MARK: | AVAJSONConvertable
    
    
    convenience required init(json: AVAJSON) throws {
        
        if let typeRaw = ((json as! NSDictionary)[AVAMutexAction.TYPE_JSON_KEY] as? NSNumber), let timestampRaw = ((json as! NSDictionary)[AVAMutexAction.TIMESTAMP_JSON_KEY] as? NSNumber) {
            if let type = AVAMutexActionType(rawValue: typeRaw.integerValue) {
                self.init(type: type, timestamp: timestampRaw.doubleValue)
            } else {
                throw AVAJSONError.invalidPayload
            }
        } else {
            throw AVAJSONError.invalidPayload
        }
    }
    
    func toJSON() -> AVAJSON {
        return [
            AVAMutexAction.TYPE_JSON_KEY: NSNumber(integer: self.type.rawValue),
            AVAMutexAction.TIMESTAMP_JSON_KEY: NSNumber(double: self.timestamp)
        ]
    }
}
