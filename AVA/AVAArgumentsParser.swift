//
//  AVAArgumentsParser.swift
//  AVA
//
//  Created by Thorsten Kober on 21.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


/**
 
 Enthält die verschiedenen Service Arten.
 
 */
enum AVAServiceType: UInt {
    
    /**
     
     Service für die Übung 1.
     
     */
    case Uebung1 = 1
    
    /**
     
     Service für die Übung 1.
     
     */
    case Uebung2 = 2
    
    
    /**
     
     Gibt die für den Service wichtigen Parameter zurück, damit andere Knoten instanziiert werden können.
     
     - parameters:
     
        - setup: Das Setup, aus welchem die Parameter für die Instanziierung entnommen werden soll.
     
     - returns: Die servicerelevanten Parameter zur Instanziierung eines neuen Knoten.
     
     */
    func nodeInstantiationParametersFromSetup(setup: AVASetup) -> [String] {
        var result = [SERVICE_PARAMETER_NAME, "\(self.rawValue)"]
        switch self {
        case .Uebung1:
            result.appendContentsOf([RUMOR_PARAMETER_NAME, setup.rumor!, RUMOR_COUNT_TO_ACCAPTENCE_PARAMETER_NAME, "\(setup.rumorCountToAcceptance!)"])
            break
            
        case .Uebung2:
            result.appendContentsOf([NODES_TO_CONTACT_COUNT_NAME, "\(setup.nodesToContactCount!)", STAKE_NAME, "\(setup.stake!)"])
            if let maxBalance = setup.maxBalance {
                result.appendContentsOf([MAX_BALANCE_NAME, "\(maxBalance)"])
            }
            break
            
        }
        return result
    }
}


let OBSERVER_PARAMETER_NAME = "--observer"
let TOPOLOGY_PARAMETER_NAME = "--topology"
let RANDOM_TOPOLOGY_PARAMETER_NAME = "--randomTopology"
let PEER_NAME_PARAMETER_NAME = "--peerName"
let RUMOR_PARAMETER_NAME = "--rumor"
let RUMOR_COUNT_TO_ACCAPTENCE_PARAMETER_NAME = "--rumorCountToAcceptance"
let SERVICE_PARAMETER_NAME = "--service"
let NODES_TO_CONTACT_COUNT_NAME = "--nodesToContact"
let STAKE_NAME = "--stake"
let MAX_BALANCE_NAME = "--maxBalance"
let LOG_DEBUG_NAME = "--logDebug"
let LOG_INFO_NAME = "--logInfo"
let LOG_WARNING_NAME = "--logWarning"
let LOG_ERROR_NAME = "--logError"
let LOG_SUCCESS_NAME = "--logSuccess"
let LOG_MEASUREMENT_NAME = "--logMeasurement"
let LOG_LIFECYCLE_NAME = "--logLifecycle"
let DISABLE_NODE_UI_LOG_NAME = "--disableNodeUILog"
let INSTANT_MEASUREMENT_NAME = "--instantMeasurement"
let NO_GRAPHVIZ_NAME = "--noGraphviz"


/**
 
 Repräsentiert die aus den Übergabeparametern enommenen Informationen.
 
 */
class AVASetup: NSObject {
    
    /**
     
     Der Pfad zum Binary der Anwendung.
     
     */
    var applicationPath: String
    
    /**
     
     Gibt an, ob dieser Knoten Beobachter ist.
     
     */
    var isObserver = false
    
    /**
     
     Gibt an, ob eine zufällige Topologie erzeugt und instanziiert werden soll.
     
     */
    var randomTopology = false
    
    /**
     
     Gibt die Dimension der zufällig zu erzeugenden Topologie an.
     
     */
    var randomTopologyDimension: AVATopologyDimension?
    
    /**
     
     Der Pfad, unter welchem eine Beschreibung der Topologie als .dot-File zu finden ist.
     
     */
    var topologyFilePath: String!
    
    /**
     
     Der Name des Knoten.
     
     */
    var peerName: String!
    
    /**
     
     Das zu verbreitende Gerücht.
     
     */
    var rumor: String?
    
    /**
     
     Die Anzahl an Knoten, von denen ein Gerücht hören muss, bevor es akzeptiert wird.
     
     */
    var rumorCountToAcceptance: Int?
    
    /**
     
     Die Anzahl an Knoten, die ein Leader kontaktieren soll.
     
     */
    var nodesToContactCount: Int?
    
    /**
     
     Der Einsatz, um den im Follower-Leader-Spiel gespielt wird.
     
     */
    var stake: Double?
    
    /**
     
     Den maximalen Betrag den ein Spieler im Leader-Follower-Spiel erspeilen soll.
     
     */
    var maxBalance: Double?
    
    /**
     
     Der Service, den der Knoten bereitstellen soll.
     
     */
    var service: AVAServiceType!
    
    /**
     
     Der Pfad zum Package (.app) der Anwendung
     
     */
    var applicationPackagePath: String {
        get {
            
            var components = self.applicationPath.componentsSeparatedByString("/")
            while (components.last != nil && !components.last!.hasSuffix(".app")) {
                components.removeLast()
            }
            return NSString.pathWithComponents(["/"] + components)
        }
    }
    
    /**
     
     Der Pfad zu dem Directory, in welchem das Package der Anwendung liegt.
     
     */
    var applicationPackageDirectory: String {
        get {
            var components = self.applicationPackagePath.componentsSeparatedByString("/")
            components.removeLast()
            return NSString.pathWithComponents(["/"] + components)
        }
    }
    
    /**
     
     Gibt an, dass Einträge des Levels Debug geloggt werden sollen.
     
     */
    var logDebug = false
    
    /**
     
     Gibt an, dass Einträge des Levels Info geloggt werden sollen.
     
     */
    var logInfo = false
    
    /**
     
     Gibt an, dass Einträge des Levels Warning geloggt werden sollen.
     
     */
    var logWarning = false
    
    /**
     
     Gibt an, dass Einträge des Levels Error geloggt werden sollen.
     
     */
    var logError = false
    
    /**
     
     Gibt an, dass Einträge des Levels Success geloggt werden sollen.
     
     */
    var logSuccess = false
    
    /**
     
     Gibt an, dass Einträge des Levels Measurement geloggt werden sollen.
     
     */
    var logMeasurement = false
    
    /**
     
     Gibt an, dass Einträge des Levels Lifecycle geloggt werden sollen.
     
     */
    var logLifecycle = false
    
    /**
     
     Gibt an, dass der Log nicht in der GUI dargestellt werden soll.
     
     */
    var disableNodeUILog = false
    
    /**
     
     Gibt an, ob ein Service selbständig Messwerte an den Beobachter senden soll oder erst bei Aufforderung.
     
     */
    var instantMeasurement = false
    
    /**
     
     Gibt an, ob der Topologie-Status mit Graphviz dargestellt werden soll.
     
     */
    var noGraphviz = false
    
    /**
     
     Erzeugt ein neues AVASetup-Objekt.
     
     - parameters:
     
        - applicationPath: Der Pfad zum Binary der Anwendung.
     
     */
    init(applicationPath: String) {
        self.applicationPath = applicationPath
        super.init()
    }
    
    
    override var description: String {
        var result = "\(super.description) {"
        result += "\n\tapplicationPath -> \(applicationPath)"
        result += "\n\tapplicationPackagePath -> \(applicationPackagePath)"
        result += "\napplicationPackageDirectory -> \(applicationPackageDirectory)"
        result += "\n\tisObserver -> \(isObserver)"
        result += "\n\trandomTopology -> \(randomTopology)"
        result += "\n\trandomTopologySize -> \(randomTopologyDimension)"
        result += "\n\ttopologyFilePath -> \(topologyFilePath)"
        result += "\n\tpeerName -> \(peerName)"
        result += "\n\trumor -> \(rumor)"
        result += "\n\trumorCountToAcceptance -> \(rumorCountToAcceptance)"
        result += "\n\tnodesToContactCount -> \(nodesToContactCount)"
        result += "\n\tstake -> \(stake)"
        result += "\n\tmaxBalance -> \(maxBalance)"
        result += "\n\tservice -> \(service)"
        result += "\n\tlogDebug -> \(logDebug)"
        result += "\n\tlogInfo -> \(logInfo)"
        result += "\n\tlogWarning -> \(logWarning)"
        result += "\n\tlogError -> \(logError)"
        result += "\n\tlogSuccess -> \(logSuccess)"
        result += "\n\tlogMeasurement -> \(logMeasurement)"
        result += "\n\tlogLifecycle -> \(logLifecycle)"
        result += "\n\tdisableNodeUILog -> \(disableNodeUILog)"
        result += "\n\tinstantMeasurement -> \(instantMeasurement)"
        result += "\n\tnoGraphviz -> \(noGraphviz)"
        result += "\n}"
        return result
    }
}


typealias AVAArgument = String


/**
 
 Ein Singleto, welches die Übergabeparameter ausliest und verarbeitet.
 
 */
class AVAArgumentsParser: NSObject {
    
    // MARK: - Shared Instance
    
    
    /**
    
     Die Instanz des Singleton.
    
     */
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
    
    
    /**
    
     Die Übergabeparameter.
    
     */
    private var arguments: [AVAArgument]?
    
    
    /**
     
     Der Index des aktuell zu verarbeitenden Arguments.
     
     */
    private var currentArgumentIndex: Int = -1
    
    
    /**
     
     Gibt das aktuell zu verarbeitende Argument zurück.
     
     - returns: Das aktuell zu verarbeitenden Arguments.
     
     */
    private func currentArgument() -> AVAArgument? {
        if let arguments = self.arguments {
            return self.currentArgumentIndex < 0 || self.currentArgumentIndex >= arguments.count ? nil : arguments[self.currentArgumentIndex]
        }
        return nil
    }
    
    
    /**
     
     Setzt den Index des aktuell zu verarbeitenden Arguments auf das nächste.
     
     - returns: Ein boolscher Wert, der angibt, ob ein nächstes Argument existiert.
     
     */
    private func nextArgument() -> Bool {
        self.currentArgumentIndex++

        return currentArgument() != nil
    }
    
    
    // MARK: - Parsing
    
    
    /**
    
     Verarbeitet eine Liste von Übergabeparametern und erzeugt daraus eine AVASetup-Instanz.
    
     Dabei wird stets nach einer Verarbeitungs-Regel für das aktuelle Argument gesucht und diese, falls vorhanden, angewandt. Existiert keine Regel wird das Argument übersprungen.
    
     - parameters:
        
        - arguments: Die Überageparameter, die verarbeitet werden sollen.
    
     - returns: Das erzeugte AVASetup.
    
     */
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
    
    
    /**
     
     Die Regeln zur verarbeitung von Übergabeparametern.
     
     */
    private lazy var parsingRules: AVAArgumentParserRules = [
        OBSERVER_PARAMETER_NAME: {(setup: AVASetup) -> () in
            setup.isObserver = true
        },
        TOPOLOGY_PARAMETER_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.topologyFilePath = (self.currentArgument()! as NSString).stringByExpandingTildeInPath
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
        NODES_TO_CONTACT_COUNT_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.nodesToContactCount = Int(self.currentArgument()!)
        },
        STAKE_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.stake = Double(self.currentArgument()!)
        },
        MAX_BALANCE_NAME: {(setup: AVASetup) -> () in
            if (!self.nextArgument()) {
                print("Missing arguments")
                exit(2)
            }
            setup.maxBalance = Double(self.currentArgument()!)
        },
        LOG_DEBUG_NAME: {(setup: AVASetup) -> () in
            setup.logDebug = true
        },
        LOG_INFO_NAME: {(setup: AVASetup) -> () in
            setup.logInfo = true
        },
        LOG_WARNING_NAME: {(setup: AVASetup) -> () in
            setup.logWarning = true
        },
        LOG_ERROR_NAME: {(setup: AVASetup) -> () in
            setup.logError = true
        },
        LOG_SUCCESS_NAME: {(setup: AVASetup) -> () in
            setup.logSuccess = true
        },
        LOG_MEASUREMENT_NAME: {(setup: AVASetup) -> () in
            setup.logMeasurement = true
        },
        LOG_LIFECYCLE_NAME: {(setup: AVASetup) -> () in
            setup.logLifecycle = true
        },
        DISABLE_NODE_UI_LOG_NAME: {(setup: AVASetup) -> () in
            setup.disableNodeUILog = true
        },
        INSTANT_MEASUREMENT_NAME: {(setup: AVASetup) -> () in
            setup.instantMeasurement = true
        },
        NO_GRAPHVIZ_NAME: {(setup: AVASetup) -> () in
            setup.noGraphviz = true
        }
    ]
}