//
//  AVALamportClock.swift
//  AVA
//
//  Created by Thorsten Kober on 09.01.16.
//  Copyright © 2016 Thorsten Kober. All rights reserved.
//

import Cocoa


let LAMPORT_CLOCK = AVALamportClock.sharedInstance


typealias AVALamportTimestamp = UInt


class AVALamportClock: NSObject {
    
    // MARK: - Shared Instance
    class var sharedInstance : AVALamportClock {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : AVALamportClock? = nil
        }
        
        dispatch_once(&Static.onceToken) {
            Static.instance = AVALamportClock()
        }
        return Static.instance!
    }
    
    
    // MARK: | Clock Value
    
    private let clockQueue = dispatch_queue_create("ava.lamport_clock", DISPATCH_QUEUE_SERIAL)
    
    
    private var _clockValue: AVALamportTimestamp = 0
    
    
    var currentTime: AVALamportTimestamp {
        get {
            return self._clockValue
        }
    }
    
    
    // MARK: | Manipulation
    
    func tick() -> AVALamportTimestamp {
        dispatch_sync(self.clockQueue) { () -> Void in
            self._clockValue++
        }
        return self.currentTime
    }
    
    
    func update(timestamp: AVALamportTimestamp) -> AVALamportTimestamp {
        dispatch_sync(self.clockQueue) { () -> Void in
            let currentValue = self._clockValue
            let maximum: AVALamportTimestamp = max(currentValue, timestamp)
            self._clockValue = maximum + 1
        }
        return self.currentTime
    }
}