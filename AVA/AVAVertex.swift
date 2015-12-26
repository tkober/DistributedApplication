//
//  AVAVertexName.swift
//  AVA
//
//  Created by Thorsten Kober on 23.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation

let TOPOLOGY_VERTICES = "vertices"
let TOPOLOGY_COMPLETE_GRAPH = "complete_graph"

let TOPOLOGY_VERTEX_NAME = "name"
let TOPOLOGY_VERTEX_IP = "ip"
let TOPOLOGY_VERTEX_PORT = "port"
let TOPOLOGY_VERTEX_ATTRIBUTES = "attributes"


typealias AVAVertexName = String


enum AVAVertexError: ErrorType {
    case ambiguousVertexDefinition(vertex: AVAVertex)
}


class AVAVertex: NSObject {
    
    var name: AVAVertexName
    
    var ip: String
    
    var port: UInt16
    
    var hasRepotedStandby = false
    
    var attributes: AVAJSON?
    
    
    init(name: AVAVertexName, ip: String, port: UInt16, attributes: AVAJSON?) {
        self.name = name
        self.ip = ip
        self.port = port
        self.attributes = attributes
    }
    
    
    convenience init(json: AVAJSON) {
        self.init(name: json[TOPOLOGY_VERTEX_NAME] as! AVAVertexName, ip: json[TOPOLOGY_VERTEX_IP] as! String, port: (json[TOPOLOGY_VERTEX_PORT] as! NSNumber).unsignedShortValue, attributes: json[TOPOLOGY_VERTEX_ATTRIBUTES])
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
    
    
    func toJSON() -> [String: AnyObject] {
        return [
            TOPOLOGY_VERTEX_NAME: self.name,
            TOPOLOGY_VERTEX_IP: self.ip,
            TOPOLOGY_VERTEX_PORT: NSNumber(unsignedShort: self.port)
        ];
    }
}


func ==(lhs: AVAVertex, rhs: AVAVertex) -> Bool {
    return lhs.name == rhs.name || (lhs.ip == rhs.ip && lhs.port == rhs.port)
}