//
//  StreamBaseItem.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Firebase

public func ==(lhs: StreamBaseItem, rhs: StreamBaseItem) -> Bool {
    return lhs.key == rhs.key
}

public class StreamBaseItem: KeyedObject, Equatable {
    public var key: String? {
        get {
            return ref?.key
        }
    }
    
    public var ref: Firebase?
    
    public var dict: [String: AnyObject] {
        return [:]
    }
    
    public var notificationName: String? {
        return nil
    }
    
    public required init(ref: Firebase?, dict: [String: AnyObject]?) {
        self.ref = ref
        if let d = dict {
            update(d)
        }
    }
    
    public func update(dict: [String: AnyObject]) {
    }
    
    public func clone() -> StreamBaseItem {
        return self.dynamicType(ref: ref, dict: dict)
    }
}
