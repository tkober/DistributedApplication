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
    
    
    let type: AVAMutexActionType
    
    
    init(type: AVAMutexActionType) {
        self.type = type
    }
    
    
    // MARK: | AVAJSONConvertable
    
    
    convenience required init(json: AVAJSON) throws {
        
        if let typeRaw = ((json as! NSDictionary)[AVAMutexAction.TYPE_JSON_KEY] as? NSNumber) {
            if let type = AVAMutexActionType(rawValue: typeRaw.integerValue) {
                self.init(type: type)
            } else {
                throw AVAJSONError.invalidPayload
            }
        } else {
            throw AVAJSONError.invalidPayload
        }
    }
    
    func toJSON() -> AVAJSON {
        return [
            AVAMutexAction.TYPE_JSON_KEY: NSNumber(integer: self.type.rawValue)
        ]
    }
}
