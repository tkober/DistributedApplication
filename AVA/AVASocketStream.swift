//
//  AVASocketStream.swift
//  AVA
//
//  Created by Thorsten Kober on 08.12.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


extension NSStreamEvent {
    
    func stringValue() -> String {
        switch self {
        case NSStreamEvent.None:
            return "None"
            
        case NSStreamEvent.OpenCompleted:
            return "OpenCompleted"
            
        case NSStreamEvent.HasBytesAvailable:
            return "HasBytesAvailable"
            
        case NSStreamEvent.HasSpaceAvailable:
            return "HasSpaceAvailable"
            
        case NSStreamEvent.ErrorOccurred:
            return "ErrorOccurred"
            
        case NSStreamEvent.EndEncountered:
            return "EndEncountered"
            
        default:
            return "Unkown"
        }
    }
}