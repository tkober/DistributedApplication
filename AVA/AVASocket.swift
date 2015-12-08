//
//  AVASocket.swift
//  AVA
//
//  Created by Thorsten Kober on 29.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


protocol AVASocketDelegate: class {
    
}



class AVAServerSocket: NSObject {
    
    
    var delegate: AVASocketDelegate!
    
    
    var vertex: AVAVertex
    
    
    var socket: Int32!
    
    
    // MARK: | Initializer
    
    
    init(vertex: AVAVertex) {
        self.vertex = vertex
    }
    
    
    // MARK: | Setup
    
    
    func setup() {
        self.socket = setup_posix_server_socket(self.vertex.port)
    }
    
    
    // MARK: | Starting and Stopping
    
    
    func start() {
        
        start_posix_server_socket(self.socket, 5, { (address: UnsafeMutablePointer<Int8>, port: in_port_t) -> Void in
            print("Accepted: \(String.fromCString(address)):\(port)")
        }) { (data: UnsafeMutablePointer<Int8>, length: Int) -> Void in
            let message = String(data: NSData(bytes: data, length: length), encoding: NSUTF8StringEncoding)
            print("Read \(length) bytes")
            print("message -> \(message)")
            free(data)
        }
    }
    
    
    func invalidate() {
    }
}


extension CFSocketCallBackType {
    
    func stringValue() -> String {
        switch self {
        case CFSocketCallBackType.NoCallBack:
            return "NoCallBack"
            
        case CFSocketCallBackType.ReadCallBack:
            return "ReadCallBack"
            
        case CFSocketCallBackType.AcceptCallBack:
            return "AcceptCallBack"
            
        case CFSocketCallBackType.DataCallBack:
            return "DataCallBack"
            
        case CFSocketCallBackType.ConnectCallBack:
            return "ConnectCallBack"
            
        case CFSocketCallBackType.WriteCallBack:
            return "WriteCallBack"
            
        default:
            return "Unkown"
        }
    }
}



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