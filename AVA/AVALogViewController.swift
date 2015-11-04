//
//  AVALogViewController.swift
//  AVA
//
//  Created by Thorsten Kober on 03.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVALogViewController: NSViewController {
    
    
    // MARK: | IB Outlets
    
    
    @IBOutlet private var tableView: NSTableView?
    @IBOutlet private var textView: NSTextView?
    @IBOutlet private weak var renderingGraphProgressIndicator: NSProgressIndicator?
    @IBOutlet private weak var graphImageView: NSImageView?

    
    // MARK: | Logs
    
    
    private var logs = [AVALogEntry]()

    
    // MARK: | Gathering Logs
    
    
    func gatherLogs(direcory: String, updateUI: Bool = true) {
        if let logFiles = AVALogViewController.logFilesInDirectory(direcory) {
            self.logs.removeAll()
            for logFile in logFiles {
                let fileContent = String(data: NSData(contentsOfFile: logFile)!, encoding: NSUTF8StringEncoding)!
                do {
                    let logs = try NSJSONSerialization.JSONObjectWithData("[\(fileContent)]".dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions(rawValue: 0)) as! [[String: AnyObject]]
                    for log in logs {
                        self.logs.append(AVALogEntry(json: log))
                    }
                } catch {
                    
                }
            }
            self.logs.sortInPlace({ (a: AVALogEntry, b: AVALogEntry) -> Bool in
                return a < b
            })
        }
    }
    
    
    // MARK: | Clearing Log Directory
    
    
    private class func logFilesInDirectory(directory: String) -> [String]? {
        do {
            let content = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(directory)
            let logs = content.filter({ (file: String) -> Bool in
                return file.hasSuffix(".dlog")
            })
            return logs
        } catch {
            return nil
        }
    }
    
    
    class func removeAllLogsFromDirectory(directory: String) {
        if let logs = logFilesInDirectory(directory) {
            for log in logs {
                let logPath = "\(directory)/\(log)"
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(logPath)
                } catch {
                    
                }
            }
        }
    }
    
    
    // MARK: | Graphviz
    
    
    func visualizeLogEntry(logEntry: AVALogEntry) {
        let appDelegate = NSApp.delegate as! AppDelegate
        let ownPeerName = appDelegate.setup.peerName!
        let topology = appDelegate.topology
        let tempFilePath = "\(appDelegate.setup.applicationPackageDirectory)/~\(ownPeerName)_\(NSDate().timeIntervalSince1970).render"
        
        do {
            let dot = GRAPHVIZ.dotFromTopology(topology, vertexDecorator: { (vertex: AVAVertex) -> AVAGraphvizVertexDecoration in
                return (logEntry.peer == vertex ? logEntry.level.graphvizsColor() :  AVAGraphvizGrey, AVAGraphvizSolid)
            }, ajacencyDecorator: { (adjacency: AVAAdjacency) -> AVAGraphvizAdjacencyDecoration in
                if let remotePeer = logEntry.remotePeer {
                    let logAdjacency = AVAAdjacency(v1: logEntry.peer, v2: remotePeer)
                    if logAdjacency == adjacency {
                        return (logEntry.event.adjacencyDirection(ownPeerToRemoteInOrder: adjacency.v1 == logEntry.peer), logEntry.level.graphvizsColor(), AVAGraphvizSolid, nil)
                    }
                }
                return (AVAGraphvizAdjacencyDirection.Undirected, AVAGraphvizGrey, AVAGraphvizSolid, nil)
            })
            try dot.writeToFile(tempFilePath, atomically: true, encoding: NSUTF8StringEncoding)
            self.renderAndUpdateGraphImage(tempFilePath)
        } catch {
            
        }
    }
    
    
    func renderAndUpdateGraphImage(tempFilePath: String) {
        GRAPHVIZ.renderPNGFromFile(tempFilePath) { (image) -> () in
            if let graphImage = image {
                self.updateGraphImage(graphImage)
            }
            do {
                try NSFileManager.defaultManager().removeItemAtPath(tempFilePath)
            } catch {
                
            }
        }
    }
    
    
    func clearGraphImage() {
        self.graphImageView?.image = nil
        self.renderingGraphProgressIndicator?.hidden = false
        self.renderingGraphProgressIndicator?.startAnimation(self)
    }
    
    
    func updateGraphImage(image: NSImage) {
        self.renderingGraphProgressIndicator?.hidden = true
        self.graphImageView?.image = image
    }

    
    
    // MARK: | Views Lifecylce
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.graphImageView?.wantsLayer = true
        self.graphImageView?.layer?.backgroundColor = NSColor.whiteColor().CGColor
    }
}



extension AVALogViewController: NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.logs.count
    }
}



extension AVALogViewController: NSTableViewDelegate {
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = tableView.makeViewWithIdentifier(tableColumn!.identifier, owner: self) as! NSTableCellView
        let logEntry = self.logs[row]
        var text: String
        switch tableColumn!.identifier {
        case "node":
            text = logEntry.peer
            break
            
        case "event":
            text = logEntry.event.stringValue()
            break
            
        case "level":
            text = logEntry.level.stringValue()
            break
            
        case "description":
            text = logEntry.entryDescription
            break
            
        case "timestamp":
            text = "\(logEntry.timestamp)"
            break
            
        default:
            text = ""
            break
        }
        result.textField?.attributedStringValue = NSAttributedString(string: text, attributes: logEntry.level.attributes())
        return result
    }
    
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        if let row = self.tableView?.selectedRow {
            self.clearGraphImage()
            self.visualizeLogEntry(self.logs[row])
            if let messageString = self.logs[row].message?.stringValue() {
                self.textView?.string = messageString
            } else {
                self.textView?.string = ""
            }
        }
    }
}