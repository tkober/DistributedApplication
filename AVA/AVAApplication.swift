//
//  AVAApplication.swift
//  AVA
//
//  Created by Thorsten Kober on 25.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


protocol AVAApplication: class {
    
    func nodeManager(nodeManager: AVANodeManager, didReceiveApplicationDataMessage message: AVAMessage)
    
}