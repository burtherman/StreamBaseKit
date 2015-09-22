//
//  String+trimPrefix.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/22/15.
//  Copyright © 2015 Steve Farrell. All rights reserved.
//

import Foundation

extension String {
    mutating func trimPrefix(prefix: String) {
        if hasPrefix(prefix) {
            removeRange(startIndex..<prefix.endIndex)
        }
    }
    
    func prefixTrimmed(prefix: String) -> String {
        if hasPrefix(prefix) {
            var copy = self
            copy.removeRange(startIndex..<prefix.endIndex)
            return copy
        }
        return self
    }
}