//
//  AVAGraphvizAdapter.swift
//  AVA
//
//  Created by Thorsten Kober on 22.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


typealias AVAGraphvizColor = String

let AVAGraphvizBlue: AVAGraphvizColor = "blue"
let AVAGraphvizGrey: AVAGraphvizColor = "grey"


typealias AVAGraphvizLineStyle = String

let AVAGraphvizSolid: AVAGraphvizLineStyle = "solid"
let AVAGraphvizDotted: AVAGraphvizLineStyle = "dotted"



enum AVAGraphvizAdjacencyDirection {
    case Undirected;
    case InOrder;
    case Inverse;
}


typealias AVAGraphvizVertexDecoration = (color: AVAGraphvizColor, style: AVAGraphvizLineStyle)
typealias AVAGraphvizVertexDecorator = (vertex: AVAVertex) -> AVAGraphvizVertexDecoration
typealias AVAGraphvizAdjacencyDecoration = (direction: AVAGraphvizAdjacencyDirection, color: AVAGraphvizColor, style: AVAGraphvizLineStyle, label: String?)
typealias AVAGraphvizAdjacencyDecorator = (adjacency: AVAAdjacency) -> AVAGraphvizAdjacencyDecoration


let GRAPHVIZ = AVAGraphvizAdapter.sharedInstance


class AVAGraphvizAdapter: NSObject {
    
    // MARK: Shared Instance
    
    
    class var sharedInstance : AVAGraphvizAdapter {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : AVAGraphvizAdapter? = nil
        }
        
        dispatch_once(&Static.onceToken) {
            Static.instance = AVAGraphvizAdapter()
        }
        return Static.instance!
    }
    
    
    // MARK: GCD
    
    
    private lazy var renderingQueue = dispatch_queue_create("ava.graphviz_adapter.rendering_queue", DISPATCH_QUEUE_SERIAL)
    
    
    // MARK: Source File Creation
    
    
    func dotFromTopology(topology: AVATopology, vertexDecorator: AVAGraphvizVertexDecorator, ajacencyDecorator: AVAGraphvizAdjacencyDecorator) -> String {
        var result = "digraph G {"
        for vertex in topology.vertices {
            result += "\n\(vertex) \(self.stringFromVertexDecoration(vertexDecorator(vertex: vertex)))"
        }
        for adjacency in topology.adjacencies {
            let decoration = ajacencyDecorator(adjacency: adjacency)
            let from: AVAVertex
            let to: AVAVertex
            if (decoration.direction == .InOrder) {
                from = adjacency.v1
                to = adjacency.v2
            } else {
                from = adjacency.v2
                to = adjacency.v1
            }
            result += "\n\(from) -> \(to) \(self.stringFromAdjacencyDecoration(decoration))"
        }
        result += "\n}"
        return result
    }
    
    
    func stringFromVertexDecoration(decoration: AVAGraphvizVertexDecoration) -> String {
        return "[color=\(decoration.color), fontcolor=\(decoration.color), style=\(decoration.style)]"
    }
    
    
    func stringFromAdjacencyDecoration(decoration: AVAGraphvizAdjacencyDecoration) -> String {
        let directionString: String
        switch (decoration.direction) {
        case .Undirected:
            directionString = ", dir=none"
            break;
            
        default:
            directionString = ""
            break;
        }
        return "[color=\(decoration.color), style=\(decoration.style)\(directionString)]"
    }


    // MARK: Rendering
    
    
    typealias AVAGraphvizRenderingCompletion = (image: NSImage?) -> ()
    
    
    func renderPNGFromFile(filePath: String, concurrent: Bool = true, result: AVAGraphvizRenderingCompletion) {
        let rendering: dispatch_block_t = { () -> Void in
            let task = NSTask()
            task.launchPath = "/usr/local/bin/dot"
            task.arguments = ["-Tpng", filePath]
            
            let pipe = NSPipe()
            task.standardOutput = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if concurrent {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    result(image: NSImage(data: data))
                })
            } else {
                result(image: NSImage(data: data))
            }
        }
        if concurrent {
            dispatch_async(self.renderingQueue) { () -> Void in
                rendering()
            }
        } else {
            rendering()
        }
    }
    
    
    
    // MARK: | Generating Graphviz File
    
    
    func graphvizFileFromAdjacencies(adjacencies: [AVAAdjacency]) -> NSData {
        var graphString = "graph g {"
        for adjacency in adjacencies {
            graphString += "\n\(adjacency.v1) -- \(adjacency.v2)"
        }
        graphString += "\n}"
        return graphString.dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    
    func graphvizFileFromTopology(topology: AVATopology) -> NSData {
        return self.graphvizFileFromAdjacencies(topology.adjacencies)
    }
}