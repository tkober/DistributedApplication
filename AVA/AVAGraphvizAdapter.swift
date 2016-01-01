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
let AVAGraphvizBlack: AVAGraphvizColor = "black"
let AVAGraphvizOrange: AVAGraphvizColor = "orange"
let AVAGraphvizRed: AVAGraphvizColor = "red"
let AVAGraphvizPurple: AVAGraphvizColor = "purple"
let AVAGraphvizGreen: AVAGraphvizColor = "green"
let AVAGraphvizPink: AVAGraphvizColor = "pink"


typealias AVAGraphvizLineStyle = String

let AVAGraphvizSolid: AVAGraphvizLineStyle = "solid"
let AVAGraphvizDotted: AVAGraphvizLineStyle = "dotted"



enum AVAGraphvizAdjacencyDirection {
    case Undirected;
    case InOrder;
    case Inverse;
}


/**
 
 Ein Tupel, welches welches beschreibt, wie Graphviz einen Knoten darstellen soll.
 
 */
typealias AVAGraphvizVertexDecoration = (color: AVAGraphvizColor, style: AVAGraphvizLineStyle)


/**
 
 Eine Closure, die dazu verwendet wird einen Knoten für Graphviz zu dekorieren.
 
 - parameters:
 
    - vertex: Der Knoten, der Dekoriert werden soll.
 
 - returns: Eine AVAGraphvizVertexDecoration, die beschreibt, wie Graphviz den gegebenen Knoten darstellen soll.
 
 */
typealias AVAGraphvizVertexDecorator = (vertex: AVAVertexName) -> AVAGraphvizVertexDecoration


/**
 
 Ein Tupel, welches beschreibt, wie Graphviz eine Kante darstellen soll.
 
 */
typealias AVAGraphvizAdjacencyDecoration = (direction: AVAGraphvizAdjacencyDirection, color: AVAGraphvizColor, style: AVAGraphvizLineStyle, label: String?)


/**
 
 Eine Closure, die dazu verwendet wird eine Kante für Graphviz zu dekorieren.
 
 - parameters:
    
    - adjacency: Die zu dekorierende Kante als AVAAdjacency-Objekt.
 
 - returns: Eine AVAGraphvizAdjacencyDecoration, die beschreibt, wie Graphviz die gegebene Kante darstellen soll.
 
 */
typealias AVAGraphvizAdjacencyDecorator = (adjacency: AVAAdjacency) -> AVAGraphvizAdjacencyDecoration


let GRAPHVIZ = AVAGraphvizAdapter.sharedInstance


/**
 
 Ein Singleton, welches in der Lage ist aus gegebenen AVATopology-Objekten beschreibungen für das Graphviz tool DOT zu generieren und diese als PNG zu rendern.
 
 */
class AVAGraphvizAdapter: NSObject {
    
    // MARK: Shared Instance
    
    
    /**
    
     Instanz des Singleton
    
     */
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
    
    
    /**
     
     Eine nebenläufige Dispatch-Queue, die dazu verwendet wird .dot-Files zu rendern.
     
     */
    
    
    private lazy var renderingQueue = dispatch_queue_create("ava.graphviz_adapter.rendering_queue", DISPATCH_QUEUE_SERIAL)
    
    
    // MARK: Source File Creation
    
    
    /**
    
     Erzeugt ein .dot-File von einer gegeben AVATopology-Instanz.
    
     - parameters:
     
       - topology: Die Topologie, die dargestellt werden soll.
    
       - vertexDecorator: Eine AVAGraphvizVertexDecorator Closure, die zur Dekoration der Knoten verwendet wird.
    
       - ajacencyDecorator: Eine AVAGraphvizAdjacencyDecorator Closure, die zur Dekoration der Kanten verwendet wird.
    
     - returns: Den Inhalt des .dot-Files als String.
    
     */
    func dotFromTopology(topology: AVATopology, vertexDecorator: AVAGraphvizVertexDecorator, renderObserver: Bool = false, adjacencyDecorator: AVAGraphvizAdjacencyDecorator) -> String {
        let topologyToRender = renderObserver ? topology : topology.topologyExcludingObserver()
        var result = "digraph G {"
        for vertex in topologyToRender.vertices {
            result += "\n\(vertex.name) \(self.stringFromVertexDecoration(vertexDecorator(vertex: vertex.name)))"
        }
        for adjacency in topologyToRender.adjacencies {
            let decoration = adjacencyDecorator(adjacency: adjacency)
            let from: AVAVertexName
            let to: AVAVertexName
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
    
    
    /**
     
     Erzeugt einen String zur Dekoration eines Knotens in einem .dot-File aus einer AVAGraphvizVertexDecoration Closure.
     
     - parameters:
     
        - decoration: Die Dekoration des Knotens.
     
     - returns: Einen String zur verwendung in einem .dot-File.
     
     */
    private func stringFromVertexDecoration(decoration: AVAGraphvizVertexDecoration) -> String {
        return "[color=\(decoration.color), fontcolor=\(decoration.color), style=\(decoration.style)]"
    }
    
    
    /**
     
     Erzeugt einen String zur Dekoration einer Kante in einem .dot-File aus einer AVAGraphvizAdjacencyDecoration Closure.
     
     - parameters:
     
        - decoration: Die Dekoration der Kante.
     
     - returns: Einen String zur verwendung in einem .dot-File.
     
     */
    private func stringFromAdjacencyDecoration(decoration: AVAGraphvizAdjacencyDecoration) -> String {
        let directionString: String
        switch (decoration.direction) {
        case .Undirected:
            directionString = ", dir=none"
            break;
            
        default:
            directionString = ""
            break;
        }
        var result = "[color=\(decoration.color), style=\(decoration.style)\(directionString)"
        if let label = decoration.label {
            result += ", label=\(label), fontcolor=\(decoration.color)"
        }
        result += "]"
        return result
    }


    // MARK: Rendering
    
    
    /**
    
     Eine Closure die als Callback für asynchrones Rendern verwendet wird.
    
     - parameters:
     
       - image: Das gerenderte Bild als NSImage-Optional.
    
     */
    typealias AVAGraphvizRenderingCompletion = (image: NSImage?) -> ()
    
    
    /**
     
     Rendert ein gegebenes .dot-File als PNG.
     
     - parameters:
     
        - filePath: Der Pfad zum .dot-File.
     
        - concurrent: Gibt an, ob das Bild synchron auf dem aktuellen Thread oder asynchron auf einem speziellen Thread gerendert werden soll.
     
        - result: Callback Closure vom Typ AVAGraphvizRenderingCompletion. Diese wird immer auf dem Main-Thread aufgerufen!
     
     - important: Alle asynchronen Renderings finden auf einem gemeinsamen Thread statt. Dies kann sich negativ auf die Performance auswirken, falls sehr viele Renderings paralell stattfinden.
     
     */
    func renderPNGFromDOTFile(filePath: String, concurrent: Bool = true, result: AVAGraphvizRenderingCompletion) {
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
            dispatch_async(self.renderingQueue, rendering)
        } else {
            rendering()
        }
    }
}
