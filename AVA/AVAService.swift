//
//  AVAApplication.swift
//  AVA
//
//  Created by Thorsten Kober on 25.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


protocol AVAService: class {
    
    // MARK: | Starting Service
    func startWithBufferedMessage(messages: [AVAMessage])
    
    
    // MARK: | Messaging
    func nodeManager(nodeManager: AVANodeManager, didReceiveApplicationDataMessage message: AVAMessage)
    
}


protocol AVAJSONConvertable {
    
    init(json: AVAJSON) throws
    func toJSON() -> AVAJSON
    
}