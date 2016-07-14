//
//  Utils.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

internal extension String {
    
    mutating func trimHTTPLine() {
        if let preEndLineIndex = index(endIndex, offsetBy: -2, limitedBy: startIndex) {
            removeSubrange(Range<Index>(uncheckedBounds: (preEndLineIndex,endIndex)))
            
        }
    }
}
