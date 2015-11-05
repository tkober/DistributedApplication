//
//  AVAArgumentsParser.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


enum AVAServiceType: UInt {
    case Uebung1 = 1
    
    func nodeInstantiationParametersFromSetup(setup: AVASetup) -> [String] {
        var result = [SERVICE_PARAMETER_NAME, "\(self.rawValue)"]
        switch self {
        case .Uebung1:
            result.appendContentsOf([RUMOR_PARAMETER_NAME, setup.rumor!, RUMOR_COUNT_TO_ACCAPTENCE_PARAMETER_NAME, "\(setup.rumorCountToAcceptance!)"])
            break
            
        }
        return result
    }
}


private let MASTER_PARAMETER_NAME = "--master"
private let TOPOLOGY_PARAMETER_NAME = "--topology"
private let RANDOM_TOPOLOGY_PARAMETER_NAME = "--randomTopology"
private let PEER_NAME_PARAMETER_NAME = "--peerName"
private let RUMOR_PARAMETER_NAME = "--rumor"
private let RUMOR_COUNT_TO_ACCAPTENCE_PARAMETER_NAME = "--rumorCountToAcceptance"
private let SERVICE_PARAMETER_NAME = "--service"


class AVASetup: NSObject {
    
    var applicationPath: String
    var isMaster = false
    var randomTopology = false
    var randomTopologyDimension: AVATopologyDimension?
    var topologyFilePath: String?
    var peerName: String?
    var rumor: String?
    var rumorCountToAcceptance: Int?
    var service: AVAServiceType!
    
    
    var applicationPackagePath: String {
        get {
            
            var components = self.applicationPath.componentsSeparatedByString("/")
            while (components.last != nil && !components.last!.hasSuffix(".app")) {
                components.removeLast()
            }
            return NSString.pathWithComponents(["/"] + components)
        }
    }
    
    
    var applicationPackageDirectory: String {
        get {
            var components = self.applicationPackagePath.componentsSeparatedByString("/")
            components.removeLast()
            return NSString.pathWithComponents(["/"] + components)
        }
    }
    
    
    init(applicationPath: String) {
        self.applicationPath = applicationPath
        super.init()
    }
    
    
    override var description: String {
        var result = "\(super.description) {"
        result += "\n\tapplicationPath -> \(applicationPath)"
        result += "\n\tapplicationPackagePath -> \(applicationPackagePath)"
        result += "\napplicationPackageDirectory -> \(applicationPackageDirectory)"
        result += "\n\tisMaster -> \(isMaster)"
        result += "\n\trandomTopology -> \(randomTopology)"
        result += "\n\trandomTopologySize -> \(randomTopologyDimension)"
        result += "\n\ttopologyFilePath -> \(topologyFilePath)"
        result += "\n\tpeerName -> \(peerName)"
        result += "\n\trumor -> \(rumor)"
        result += "\n\trumorCountToAcceptance -> \(rumorCountToAcceptance)"
        result += "\n\tservice -> \(service)"
        result += "\n}"
        return result
    }
}


typealias AVAArgument = String


class AVAArgumentsParser: NSObject {
    
    // MARK: - Shared Instance
    
    
    class var sharedInstance : AVAArgumentsParser {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : AVAArgumentsParser? = nil
        }
        
        dispatch_once(&Static.onceToken) {
            Static.instance = AVAArgumentsParser()
        }
        return Static.instance!
    }
    
    
    // MARK: - Arguments
    
    
    private var arguments: [AVAArgument]?
    
    
    private var currentArgumentIndex: Int = -1
    
    
    private func currentArgument() -> AVAArgument? {
        if let arguments = self.arguments {
            return self.currentArgumentIndex < 0 || self.currentArgumentIndex >= arguments.count ? nil : arguments[self.currentArgumentIndex]
        }
        return nil
    }
    
    
    private func nextArgument() -> Bool {
        self.currentArgumentIndex++

        return currentArgument() != nil
    }
    
    
    // MARK: - Parsing
    
    
    func parseArguments(arguments: [AVAArgument]) -> AVASetup {
        self.arguments = arguments
        if !nextArgument() {
            exit(1)
        }
        let result = AVASetup(applicationPath: currentArgument()!)
        
        while (self.nextArgument()) {
            if let processing = self.parsingRules[self.currentArgument()!] {
                processing(setup: result)
            } else {
                print("Unkown argument '\(self.currentArgument()!)'")
            }
        }
        
        return result
    }
    
    
    // MARK: - Rules
    
    
    private typealias AVARuleProcessing = (setup: AVASetup) -> ()
    private typealias AVAArgumentParserRules = [String: AVARuleProcessing]
    
    
    private lazy var parsingRules: AVAArgumentParserRules = [
        MASTER_PARAMETER_NAME: {(setup: AVASetup) -> () in
            setup.isMaster = true
        },
        TOPOLOGY_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.topologyFilePath = self.currentArgument()
        },
        RANDOM_TOPOLOGY_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            let vertexCount = Int(self.currentArgument()!)!
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            let edgeCount = Int(self.currentArgument()!)!
            if vertexCount > edgeCount {
                print("Number of vertices is greater than the number of edges")
                exit(2)
            }
            setup.randomTopology = true
            setup.randomTopologyDimension = (vertexCount, edgeCount)
        },
        PEER_NAME_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.peerName = self.currentArgument()
        },
        RUMOR_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.rumor = self.currentArgument()
        },
        RUMOR_COUNT_TO_ACCAPTENCE_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.rumorCountToAcceptance = Int(self.currentArgument()!)
        },
        SERVICE_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.service = AVAServiceType(rawValue: UInt(self.currentArgument()!)!)
        },
        
    ]
}