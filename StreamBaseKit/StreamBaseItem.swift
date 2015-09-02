//
//  StreamBaseItem.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Firebase

/**
    A base class for objects persisted in Firebase that make up the
    items in streams.
 */
public class StreamBaseItem: KeyedObject, Equatable {
    /**
        The final part of the firebase path.
    */
    public var key: String?
    
    /**
        A ref to the firebase backing store, including key.
    */
    public var ref: Firebase?
        
    /**
        Create an empty instance.  Typically used for constructing new instances
        where the key and ref are filled in later.
    */
    public convenience init() {
        self.init(key: nil, ref: nil, dict: nil)
    }
    
    /**
        Create an instance initialized to a key.  This object may not yet be
        backed by firebase data.
    
        :param: key    The key, or final part of a firebase path.
    */
    public convenience init(key: String?) {
        self.init(key: key, ref: nil, dict: nil)
    }

    /**
        Create an instance initialized to a firebase ref.
    
        :param: ref    The firebase ref.
    */
    public convenience init(ref: Firebase?) {
        self.init(key: ref?.key, ref: ref, dict: nil)
    }

    /**
        Create an instance initialized to snapshot data.  If the snapshot value is
        empty, return nil (even if the key and ref are valid).
    
        :param: snap    The firebase snapshot.
     */
    public convenience init?(snap: FDataSnapshot) {
        if let d = snap.value as? [String: AnyObject] {
            self.init(key: snap.key, ref: snap.ref, dict: d)
        } else {
            // "For classes, however, a failable initializer can trigger an initialization 
            // failure only after all stored properties introduced by that class have been 
            // set to an initial value and any initializer delegation has taken place."
            self.init()
            return nil
        }
    }

    /**
        Create an instance fully initialized with the key, ref and data.

        :param: key The last part of the firebase path
        :param: ref The full firebase reference (including key)
        :param: dict    The data with which to populate this object
    */
    public required init(key: String?, ref: Firebase?, dict: [String: AnyObject]?) {
        self.key = key
        self.ref = ref
        if let d = dict {
            update(d)
        }
    }
    
    /**
        Produce a shallow copy of this object.
    */
    public func clone() -> StreamBaseItem {
        return self.dynamicType(key: key, ref: ref, dict: dict)
    }
    
    /**
        Subclasses should override to initialize fields.
    
        :param: dict    The dictionary containing the values of the fields.
     */
    public func update(dict: [String: AnyObject]) {
    }
    
    /**
        Used for persisting data to firebase.  Subclasses should override,
        appending their fields to this dictionary.
    */
    public var dict: [String: AnyObject] {
        return [:]
    }
}

// NOTE: This would make more sense on KeyedObject, but Swift 1.2 doesn't support
// Equatable protocols.
public func ==(lhs: StreamBaseItem, rhs: StreamBaseItem) -> Bool {
    return lhs.key == rhs.key
}


