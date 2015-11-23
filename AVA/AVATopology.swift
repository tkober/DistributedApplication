//
//  AVATopology.swift
//  AVA
//
//  Created by Thorsten Kober on 22.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


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
    
    
    // MARK: | Initializer
    
    
    /**
    
    Erzeugt eine Topologie aus einem .dot-File.
    
    - parameters:
    
    - graphPath: Der Inhalt des .dot-Files.
    
    */
    init(graph: NSData) {
        var graphString = String(data: graph, encoding: NSUTF8StringEncoding)!
        graphString = graphString.stringByReplacingOccurrencesOfString("\n", withString: ";")
        
        graphString = graphString.stringByReplacingOccurrencesOfString(" ", withString: "")
        var adjacencies = [AVAAdjacency]()
        
        var regex: NSRegularExpression
        do {
            try regex = NSRegularExpression(pattern: "(.*)(\\{)(.+)(\\})(.*)", options: NSRegularExpressionOptions(rawValue: 0))
            let match = regex.firstMatchInString(graphString, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, graphString.characters.count))!
            graphString = (graphString as NSString).substringWithRange(match.rangeAtIndex(3))
            
            try regex = NSRegularExpression(pattern: "([a-zA-Z0-9]+)(--)([a-zA-Z0-9]+)", options: NSRegularExpressionOptions(rawValue: 0))
            
            regex.enumerateMatchesInString(graphString, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, graphString.characters.count), usingBlock: { (match: NSTextCheckingResult?, flags: NSMatchingFlags, _) -> Void in
                let lhs = (graphString as NSString).substringWithRange(match!.rangeAtIndex(1))
                let rhs = (graphString as NSString).substringWithRange(match!.rangeAtIndex(3))
                let adjacency = AVAAdjacency(v1: lhs, v2: rhs)
                let alreadyIncluded = adjacencies.contains({ (item: AVAAdjacency) -> Bool in
                    return item == adjacency
                })
                if !alreadyIncluded {
                    adjacencies.append(adjacency)
                }
            })
        } catch {
            
        }
        self.adjacencies = adjacencies
        self.vertices = [AVAVertex]()
        super.init()
    }
    
    
    
    init(data: NSData) throws {
        // Dummy
        self.adjacencies = [AVAAdjacency]()
        self.vertices = [AVAVertex]()
        super.init()
        
        
        let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
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
    
    
    
    /**
     
     Erzeugt eine Topologie aus einem .dot-File.
     
     - parameters: 
     
        - graphPath: Der Pfad zu dem .dot-File.
     
     */
    convenience init(graphPath: String) throws {
        let data = NSData(contentsOfFile: graphPath)!
        try self.init(data: data)
    }
    
    
    /**
     
     Erzeugt eine neue zufällige Topologie mit einer gegeben Dimension.
     
     
     - parameters: 
     
        - dimension: Die Dimension der zu erzeugenden Topologie.
     
     */
    convenience init(randomWithDimension dimension: AVATopologyDimension) {
        var vertices = [AVAVertexName]()
        for (var i = 1; i <= dimension.vertexCount; i++) {
            vertices.append("\(i)")
        }
        var adjacencies = [AVAAdjacency]()
        
        var j = 0
        var v1: AVAVertexName
        while (adjacencies.count < dimension.edgeCount) {
            v1 = vertices[j]
            var v2 = v1
            while (v1 == v2) {
                v2 = vertices[Int(arc4random_uniform(UInt32(vertices.count)))]
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
        self.init(graph: GRAPHVIZ.graphvizFileFromAdjacencies(adjacencies))
    }
}