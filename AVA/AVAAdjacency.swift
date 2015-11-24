//
//  AVAAdjacency.swift
//  AVA
//
//  Created by Thorsten Kober on 23.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


let TOPOLOGY_ADJACENCIES = "adjacencies"


/**
 
 Repräsentiert zwei adjazente Knoten.
 
 */
class AVAAdjacency: NSObject {
    
    let v1: AVAVertexName
    let v2: AVAVertexName
    
    
    init(v1: AVAVertexName, v2: AVAVertexName) {
        self.v1 = v1
        self.v2 = v2
    }
    
    
    convenience init(json: [AVAJSON]) {
        let v1 = json[0] as! AVAVertexName
        let v2 = json[1] as! AVAVertexName
        self.init(v1:v1, v2:v2)
    }
    
    
    override var description: String {
        return "\(super.description) { \(v1) -- \(v2) }"
    }
    
    
    func toJSON() -> [String] {
        return [self.v1, self.v2]
    }
}


/**
 
 == Operatoer welcher zwei AVAAdjacency-Objekte auf Gleichheit prüft.
 
 */
func ==(lhs: AVAAdjacency, rhs: AVAAdjacency) -> Bool {
    return (lhs.v1 == rhs.v1 && lhs.v2 == rhs.v2) || (lhs.v1 == rhs.v2 && lhs.v2 == rhs.v1)
}


/**
 
 != Operatoer welcher zwei AVAAdjacency-Objekte auf Ungleichheit prüft.
 
 */
func !=(lhs: AVAAdjacency, rhs: AVAAdjacency) -> Bool {
    return !(lhs == rhs)
}