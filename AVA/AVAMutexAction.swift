//
//  AVAMutexAction.swift
//  AVA
//
//  Created by Thorsten Kober on 05.01.16.
//  Copyright © 2016 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVAMutexAction: NSObject, AVAJSONConvertable {
    
    
    // MARK: | AVAJSONConvertable
    
    
    convenience required init(json: AVAJSON) throws {
        self.init()
    }
    
    func toJSON() -> AVAJSON {
        return []
    }
}
