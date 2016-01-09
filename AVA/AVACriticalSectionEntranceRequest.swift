//
//  AVACriticalSectionEntranceRequest.swift
//  AVA
//
//  Created by Thorsten Kober on 06.01.16.
//  Copyright © 2016 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVACriticalSectionEntranceRequest: NSObject {
    
    let timestamp: NSTimeInterval
    
    
    let lamportTimestamp: AVALamportTimestamp
    
    
    let node: AVAVertexName
    
    
    var nodesToConfirm = [AVAVertexName]()
    
    
    init(node: AVAVertexName, timestamp: NSTimeInterval, lamportTimestamp: AVALamportTimestamp) {
        self.node = node
        self.timestamp = timestamp
        self.lamportTimestamp = lamportTimestamp
    }
    
    
    override var description: String {
        return "<\(super.description):: peer -> \(self.node), timestamp -> \(self.timestamp), lamportTimestamp -> \(self.lamportTimestamp)>"
    }
}



func <(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp < rhs.timestamp
}


func <=(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp <= rhs.timestamp
}


func >(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp > rhs.timestamp
}


func >=(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp >= rhs.timestamp
}


func ==(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp == rhs.timestamp
}


func !=(lhs: AVACriticalSectionEntranceRequest, rhs: AVACriticalSectionEntranceRequest) -> Bool {
    return lhs.timestamp != rhs.timestamp
}