//
//  AVALeaderFollowerInstance.swift
//  AVA
//
//  Created by Thorsten Kober on 27.12.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


let LEADER_STRATEGY_ATTRIBUTE = "leader_strategy"

enum AVALeaderStrategy: Int {
    
    case OfferNothing = 0
    
    case Offer1Third
    
    case Offer2Third
    
    case OfferEverything
    
}


let FOLLOWER_STRATEGY_ATTRIBUTE = "follower_strategy"

enum AVAFollowerStrategy: Int {
    
    case AlwaysAccept = 0
    
    case AcceptAtLeast1Third
    
    case AcceptAtLeast2Third
    
    case AcceptEverythingOnly
    
}


/**
 
 Alle Exceptions die von einem AVALeaderFollowerInstance-Objekt geworfen werden können.
 
 */
enum AVALeaderFollowerInstanceError: ErrorType {
    
    /**
     
     Zeigt an, dass im JSON nicht alle Informationen vorhanden sind um eine AVALeaderProposal-Instanz zu erstellen.
     
     */
    case invalidPayload
    
    /**
     
     Zeigt an, dass der im JSON enthaltene numerische Wert keiner validen Strategie entspricht.
     
     */
    case invalidStrategyValue
    
    /**
     
     Zeigt an, dass der im JSON enthaltene numerische Wert keinem validen Ergebnis entspricht.
     
     */
    case invalidResultValue
}


enum AVALeaderFollowerInstanceResult: Int {
    
    case NoFollowerStrategy
    
    case Accepted
    
    case Declined
}


class AVALeaderFollowerInstance: NSObject, AVAJSONConvertable {
    
    
    private static let LEADER_STRATEGY_KEY = "strategy"
    private static let RESULT_KEY = "result"
    private static let HALT_KEY = "halt"
    
    let leaderStrategy: AVALeaderStrategy
    
    var result: AVALeaderFollowerInstanceResult?
    
    var halt = false
    
    
    // MARK: | Initializer
    
    init(leaderStrategy: AVALeaderStrategy, result: AVALeaderFollowerInstanceResult? = nil) {
        self.leaderStrategy = leaderStrategy
        self.result = result
    }
    
    
    // MARK: | AVAJSONConvertable
    
    convenience required init(json: AVAJSON) throws {
        if let strategyRaw = ((json as! NSDictionary)[AVALeaderFollowerInstance.LEADER_STRATEGY_KEY] as? NSNumber) {
            if let strategy = AVALeaderStrategy(rawValue: strategyRaw.integerValue) {
                var result: AVALeaderFollowerInstanceResult? = nil
                if let resultRaw = ((json as! NSDictionary)[AVALeaderFollowerInstance.RESULT_KEY] as? NSNumber) {
                    if let resultValue = AVALeaderFollowerInstanceResult(rawValue: resultRaw.integerValue) {
                        result = resultValue
                    } else {
                        throw AVALeaderFollowerInstanceError.invalidResultValue
                    }
                }
                if let halt = ((json as! NSDictionary)[AVALeaderFollowerInstance.HALT_KEY] as? NSNumber) {
                    self.init(leaderStrategy: strategy, result: result)
                    self.halt = halt.boolValue
                } else {
                    throw AVALeaderFollowerInstanceError.invalidPayload
                }
            } else {
                throw AVALeaderFollowerInstanceError.invalidStrategyValue
            }
        } else {
            throw AVALeaderFollowerInstanceError.invalidPayload
        }
    }
    
    
    func toJSON() -> AVAJSON {
        var json: [String: AnyObject] = [
            AVALeaderFollowerInstance.LEADER_STRATEGY_KEY: NSNumber(integer: self.leaderStrategy.rawValue),
            AVALeaderFollowerInstance.HALT_KEY: NSNumber(bool: self.halt)
        ]
        if let result = self.result {
            json[AVALeaderFollowerInstance.RESULT_KEY] = NSNumber(integer: result.rawValue)
        }
        return json
    }
}
