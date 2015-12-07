//
//  AVATopology.swift
//  AVA
//
//  Created by Thorsten Kober on 22.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


let START_PORT: UInt16 = 5000


/**
 
 Ein Tupel, welches die Anzahl an Knoten und Kanten einer Topologie enthält.
 
 */
typealias AVATopologyDimension = (vertexCount: Int, edgeCount: Int)


/**
 
 Repräsentiert eine Topologie als Menge adjazenter Knoten.
 
 */
class AVATopology: NSObject {
    
    
    /**
     
     Die Adjazenzen der Topologie.
     
     */
    var adjacencies: [AVAAdjacency]
    
    
    /**
     
     Aller Knoten der Topologie.
     
     */
    var vertices: [AVAVertex]
    
    
    /**
     
     Die Dimension, sprich Anzahl an Kanten und Knote , der Topologie.
     
     */
    var dimension: AVATopologyDimension {
        get {
            return (self.vertices.count, self.adjacencies.count)
        }
    }
    
    
    /**
     
     Gibt alle Knoten zurück, die zu einem gegebenen Knoten adjazent sind.
     
     - parameters:
     
        - vertex: Der Knoten, dessen adjazente Knoten gesucht sind.
     
     - returns: Alle adjazenten Knoten.
     
     */
    func adjacentVerticesForVertex(vertex: AVAVertexName) -> [AVAVertexName] {
        var result: [AVAVertexName] = []
        for adjacency in adjacencies {
            if adjacency.v1 == vertex {
                result.append(adjacency.v2)
            } else if adjacency.v2 == vertex {
                result.append(adjacency.v1)
            }
        }
        return result
    }
    
    
    override var description: String {
        var result = "\(super.description) {"
        for adjacency in self.adjacencies {
            result += "\n\t\(adjacency)"
        }
        result += "\n}"
        return result
    }
    
    
    // Querying Vertices
    
    
    func vertextForName(name: AVAVertexName) -> AVAVertex? {
        for vertex in self.vertices {
            if vertex.name == name {
                return vertex
            }
        }
        return nil
    }
    
    
    // MARK: | Initializer
    
    
    init(json: AVAJSON) throws {
        self.adjacencies = [AVAAdjacency]()
        self.vertices = [AVAVertex]()
        super.init()
        
        let verticesJSON = json[TOPOLOGY_VERTICES] as! [AVAJSON]
        let adjacenciesJSON = json[TOPOLOGY_ADJACENCIES] as! [[AVAJSON]]
        
        self.vertices = try AVAVertex.verticesFromJSON(verticesJSON)
        
        for adjacencyJSON in adjacenciesJSON {
            let adjacency = AVAAdjacency(json: adjacencyJSON)
            let alreadyIncluded = self.adjacencies.contains({ (item: AVAAdjacency) -> Bool in
                return item == adjacency
            })
            if !alreadyIncluded {
                self.adjacencies.append(adjacency)
            }
        }
    }
    
    
    convenience init(data: NSData) throws {
        let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        try self.init(json: json)
    }
    
    
    convenience init(jsonPath: String) throws {
        let data = NSData(contentsOfFile: jsonPath)!
        try self.init(data: data)
    }

    
    
    /**
     
     Erzeugt eine neue zufällige Topologie mit einer gegeben Dimension.
     
     
     - parameters: 
     
        - dimension: Die Dimension der zu erzeugenden Topologie.
     
     */
    convenience init(randomWithDimension dimension: AVATopologyDimension) throws {
        var vertices = [AVAVertex]()
        for (var i = 1; i <= dimension.vertexCount; i++) {
            vertices.append(AVAVertex(name: "\(i)", ip: "localhost", port: START_PORT+UInt16(i)))
        }
        var adjacencies = [AVAAdjacency]()
        
        var j = 0
        var v1: AVAVertexName
        while (adjacencies.count < dimension.edgeCount) {
            v1 = vertices[j].name
            var v2 = v1
            while (v1 == v2) {
                v2 = vertices[Int(arc4random_uniform(UInt32(vertices.count)))].name
            }
            let newAdjacency = AVAAdjacency(v1: v1, v2: v2)
            let alreadyIncluded = adjacencies.contains({ (item: AVAAdjacency) -> Bool in
                return item == newAdjacency
            })
            if !alreadyIncluded {
                adjacencies.append(newAdjacency)
                j++
                j = j % dimension.vertexCount
            }
        }
        
        let topologyJSON = AVATopology.jsonFromVertices(vertices, adjacencies: adjacencies)
        try self.init(json: topologyJSON)
    }
    
    
    // MARK: | Export
    
    
    private static func jsonFromVertices(vertices: [AVAVertex], adjacencies: [AVAAdjacency]) -> NSDictionary {
        var verticesJSON = [[String: AnyObject]]()
        for vertex in vertices {
            verticesJSON.append(vertex.toJSON())
        }
        
        var adjacenciesJSON = [[String]]()
        for adjacency in adjacencies {
            adjacenciesJSON.append(adjacency.toJSON())
        }
        
        return [
            TOPOLOGY_VERTICES: verticesJSON,
            TOPOLOGY_ADJACENCIES: adjacenciesJSON
        ]
    }
    
    
    func toData() throws -> NSData {
        let topologyJSON = AVATopology.jsonFromVertices(self.vertices, adjacencies: self.adjacencies)
        return try NSJSONSerialization.dataWithJSONObject(topologyJSON, options: NSJSONWritingOptions.PrettyPrinted)
    }
}