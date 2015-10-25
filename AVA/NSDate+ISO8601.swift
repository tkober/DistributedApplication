//
//  NSDate+ISO8601.swift
//  AVA
//
//  Created by Thorsten Kober on 25.10.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

import Foundation


let ISO_8601_DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
let EN_US_POSIX_LOCALE = "en_US_POSIX"


extension NSDate {

    func iso8601Representation() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: EN_US_POSIX_LOCALE)
        dateFormatter.dateFormat = ISO_8601_DATE_FORMAT
        return dateFormatter.stringFromDate(self)
    }
    
    
    static func dateFromISO8601Representation(dateString: String) -> NSDate? {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: EN_US_POSIX_LOCALE)
        dateFormatter.dateFormat = ISO_8601_DATE_FORMAT
        return dateFormatter.dateFromString(dateString)
    }
    
}