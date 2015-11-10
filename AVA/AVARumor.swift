//
//  AVARumor.swift
//  AVA
//
//  Created by Thorsten Kober on 28.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


/**
 
 Alle Exceptions die von einem AVARumor-Objekt geworfen werden können.
 
 */
enum AVARumorError: ErrorType {
    
    /**
     
     Zeigt an, dass im JSON nicht alle Informationen vorhanden sind um eine AVARumor-Instanz zu erstellen.
     
     */
    case invalidPayload
}


/**
 
 Stellt ein Gerücht dar, welches sich in der Topologie verbereitet werden kann.
 
 */
class AVARumor: NSObject, AVAJSONConvertable {
    
    private static let RUMOR_TEXT_KEY = "rumorText"
    
    /**
     
     Der Inhalt des Gerüchts.
     
     */
    let rumorText: String
    
    /**
     
     Alle Knoten, von denen Dieses Gerücht gehört wurde.
     
     */
    var heardFrom = [AVAVertex]()
    
    /**
     
     Gibt an, ob das Gerücht bereits geglaubt wurde.
     
     */
    var accepted = false
    
    
    // MARK: | Initializer
    
    
    /**
    
     Erstellt eine neue Instanz mit einem gegeben Inhalt.
    
     - parameters:
    
       - rumor: Der Inhalt des zu erstellenden Gerüchts.
    
     */
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


/**
 
 == Operator zum Prüfen auf Gleichheit zweier AVARumor-Instanzen. Gegenstück wird über Generics
 
 */
func ==(lhs: AVARumor, rhs: AVARumor) -> Bool {
    return lhs.rumorText == rhs.rumorText
}
