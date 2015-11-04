//
//  AVALogViewController.swift
//  AVA
//
//  Created by Thorsten Kober on 03.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Cocoa


class AVALogViewController: NSViewController {

    
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
}