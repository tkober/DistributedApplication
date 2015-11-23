//
//  AVAVertexName.swift
//  AVA
//
//  Created by Thorsten Kober on 23.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


typealias AVAVertexName = String


enum AVAVertexError: ErrorType {
    case ambiguousVertexDefinition(vertex: AVAVertex)
}


class AVAVertex: NSObject {
    
    var name: AVAVertexName
    
    var ip: String
    
    var port: Int
    
    
    init(name: AVAVertexName, ip: String, port: Int) {
        self.name = name
        self.ip = ip
        self.port = port
    }
    
    
    convenience init(json: AVAJSON) {
        self.init(name: json["name"] as! AVAVertexName, ip: json["ip"] as! String, port: (json["port"] as! NSNumber).integerValue)
    }
    
    
    static func verticesFromJSON(json: AVAJSON) throws -> [AVAVertex] {
        var result = [AVAVertex]()
        for vertexJSON in (json as! [AVAJSON]) {
            let vertex = AVAVertex(json: vertexJSON)
            if result.contains(vertex) {
                throw AVAVertexError.ambiguousVertexDefinition(vertex: vertex)
            }
            result.append(vertex)
        }
        return result
    }
    
    
    override func isEqual(object: AnyObject?) -> Bool {
        guard object != nil else {
            return false
        }
        if object is AVAVertex {
            return object as! AVAVertex == self
        } else {
            return false
        }
    }
    
    
    override var description: String {
        var result = "\(super.description) {"
        result += "\n\tname -> \(self.name)"
        result += "\n\tip -> \(self.ip)"
        result += "\nport -> \(self.port)"
        result += "\n}"
        return result
    }
}


func ==(lhs: AVAVertex, rhs: AVAVertex) -> Bool {
    return lhs.name == rhs.name || (lhs.ip == rhs.ip && lhs.port == rhs.port)
}