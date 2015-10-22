//
//  AVATopology.swift
//  AVA
//
//  Created by Thorsten Kober on 22.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


typealias AVAVertex = String


class AVAAdjacency: NSObject {
    
    let v1: AVAVertex
    let v2: AVAVertex
    
    
    init(v1: AVAVertex, v2: AVAVertex) {
        self.v1 = v1
        self.v2 = v2
    }
    
    
    override var description: String {
        return "\(super.description) { \(v1) -- \(v2) }"
    }
}


func ==(lhs: AVAAdjacency, rhs: AVAAdjacency) -> Bool {
    return (lhs.v1 == rhs.v1 && lhs.v2 == rhs.v2) || (lhs.v1 == rhs.v2 && lhs.v2 == rhs.v1)
}


func !=(lhs: AVAAdjacency, rhs: AVAAdjacency) -> Bool {
    return !(lhs == rhs)
}



class AVATopology: NSObject {
    
    
    let adjacencies: [AVAAdjacency]
    
    
    var vertices: [AVAVertex] {
        get {
            var result: [AVAVertex] = []
            for adjacency in self.adjacencies {
                if !result.contains(adjacency.v1) {
                    result.append(adjacency.v1)
                }
                if !result.contains(adjacency.v2) {
                    result.append(adjacency.v2)
                }
            }
            return result
        }
    }
    
    
    func adjacentVerticesForVertex(vertex: AVAVertex) -> [AVAVertex] {
        var result: [AVAVertex] = []
        for adjacency in adjacencies {
            if adjacency.v1 == vertex {
                result.append(adjacency.v2)
            } else if adjacency.v2 == vertex {
                result.append(adjacency.v1)
            }
        }
        return result
    }
    
    
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
        super.init()
    }
    
    
    convenience init(graphPath: String) {
        let data = NSData(contentsOfFile: graphPath)!
        self.init(graph: data)
    }
    
    
    override var description: String {
        var result = "\(super.description) {"
        for adjacency in self.adjacencies {
            result += "\n\t\(adjacency)"
        }
        result += "\n}"
        return result
    }
}