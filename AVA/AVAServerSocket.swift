//
//  AVASocket.swift
//  AVA
//
//  Created by Thorsten Kober on 29.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


typealias AVASocketConnectionInfo = (address: String, port: in_port_t)



protocol AVAServerSocketDelegate: class {
    
    func serverSocket(socket: AVAServerSocket, acceptedConnection connection: AVASocketConnectionInfo)
    
    func serverSocket(socket: AVAServerSocket, readData data: NSData)
}



class AVAServerSocket: NSObject {
    
    
    var delegate: AVAServerSocketDelegate!
    
    
    var vertex: AVAVertex
    
    
    var socket: Int32!
    
    
    private lazy var processingQueue: dispatch_queue_t = dispatch_queue_create("ava.server_socket.processing_queue", DISPATCH_QUEUE_SERIAL)
    
    
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
        
        start_posix_server_socket(self.socket, 50, { (address: UnsafeMutablePointer<Int8>, port: in_port_t) -> Void in
            
            let connectionInfo: AVASocketConnectionInfo = (String.fromCString(address)!, port)
            self.delegate.serverSocket(self, acceptedConnection: connectionInfo)
            
        }) { (data: UnsafeMutablePointer<Int8>, length: Int) -> Void in
            let readData = NSData(bytes: data, length: length)
            dispatch_async(self.processingQueue, { () -> Void in
                self.delegate.serverSocket(self, readData: readData)
//                free(data)
            })
        }
    }
    
    
    func invalidate() {
    }
}