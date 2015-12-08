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



protocol AVASocketStreamDelegate {
    
    func socketStreamDidConnection(stream: AVASocketStream)
    
    
    func socketStreamIsReadyToSend(stream: AVASocketStream)
    
    
    func socketStreamDidDisconnect(stream: AVASocketStream)
    
    
    func socketStreamFailed(stream: AVASocketStream, status: NSStreamStatus, error: NSError?)
    
}



class AVASocketStream: NSObject {
    

    let vertex: AVAVertex
    
    
    let runloop: NSRunLoop
    
    
    var delegate: AVASocketStreamDelegate?
    
    
    // MARK: | Initializer
    
    
    init(vertex: AVAVertex, runloop: NSRunLoop = NSRunLoop.currentRunLoop()) {
        self.vertex = vertex
        self.runloop = runloop
        super.init()
        
        var readStream:  Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, vertex.ip, UInt32(vertex.port), &readStream, &writeStream)
        
        self.inputStream = readStream!.takeRetainedValue()
        self.outputStream = writeStream!.takeRetainedValue()
        
        self.inputStream.delegate = self
        self.outputStream.delegate = self
    }
    
    
    // MARK: | Open and Close
    
    
    func open() {
        self.inputStream.scheduleInRunLoop(self.runloop, forMode: NSDefaultRunLoopMode)
        self.outputStream.scheduleInRunLoop(self.runloop, forMode: NSDefaultRunLoopMode)
        
        self.inputStream.open()
        self.outputStream.open()
    }
    
    
    func close() {
        self.inputStream.removeFromRunLoop(self.runloop, forMode: NSDefaultRunLoopMode)
        self.outputStream.removeFromRunLoop(self.runloop, forMode: NSDefaultRunLoopMode)
        
        self.inputStream.close()
        self.outputStream.close()
    }
    
    
    // MARK: | Writing
    
    
    func writeData(data: NSData) {
        self.outputStream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
    }
    
    
    private var inputStream: NSInputStream!
    private var outputStream: NSOutputStream!
    
}



extension AVASocketStream: NSStreamDelegate {

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
            
        case NSStreamEvent.None:
            break
            
        case NSStreamEvent.OpenCompleted:
            self.delegate?.socketStreamDidConnection(self)
            
        case NSStreamEvent.HasBytesAvailable:
            break
            
        case NSStreamEvent.HasSpaceAvailable:
            self.delegate?.socketStreamIsReadyToSend(self)
            
        case NSStreamEvent.ErrorOccurred:
            self.delegate?.socketStreamFailed(self, status: aStream.streamStatus, error: aStream.streamError)
            
        case NSStreamEvent.EndEncountered:
            self.delegate?.socketStreamDidDisconnect(self)
            
        default:
            break
            
        }
    }
    
}



