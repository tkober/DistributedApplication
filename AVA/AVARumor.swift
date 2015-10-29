//
//  AVARumor.swift
//  AVA
//
//  Created by Thorsten Kober on 28.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


enum AVARumorError: ErrorType {
    case invalidPayload
}


class AVARumor: NSObject, AVAJSONConvertable {
    
    private static let RUMOR_TEXT_KEY = "rumorText"
    
    private let rumorText: String
    
    var heardFrom = [AVAVertex]()
    
    
    // MARK: | Initializer
    
    
    init(rumor: String) {
        self.rumorText = rumor
        super.init()
    }
    
    
    // MARK: | AVAJSONConvertable
    
    
    convenience required init(json: AVAJSON) throws {
        if let rumorText = (json as! [String: String])[AVARumor.RUMOR_TEXT_KEY] {
            self.init(rumor: rumorText)
        } else {
            throw AVARumorError.invalidPayload
        }
    }
    
    
    func toJSON() -> AVAJSON {
        return [AVARumor.RUMOR_TEXT_KEY: self.rumorText]
    }
}


func ==(lhs: AVARumor, rhs: AVARumor) -> Bool {
    return lhs.rumorText == rhs.rumorText
}
