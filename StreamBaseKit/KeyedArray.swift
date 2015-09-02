//
//  KeyedArray.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation

/**
    An object with an identifiying key, such as those found in the hierarchical 
    Firebase data model.
*/
public protocol KeyedObject: class {
    var key: String? { get }
}

/**
    A Collection that wraps both an array and dictionary.  It has O(1) access
    by index or key and for appends, but is O(n) for inserts and deletes.  The
    objects it contains are expected to have unique keys.
*/
public class KeyedArray<T: KeyedObject> {
    private(set) var rawArray = [T]()
    private var index = [String: Int]()
    
    /**
        Construct an instance initialized to contain specific objects.
        
        :param: objects The objects to initialize the array from.
    */
    public convenience init(objects: T...) {
        self.init(rawArray: objects)
    }

    /**
        Construct an instance initialized to the contents of an array.

        :param: rawArray    The raw array to initialize from.
    */
    public init(rawArray: [T]) {
        extend(rawArray)
    }
    
    /**
        Get the index of a given key.
        
        :param: key The key to check for.
        :returns:    The index, or nil if the key is not present.
    */
    public func find(key: String) -> Int? {
        if let i = index[key] {
            return i
        }
        return nil
    }
    
    /**
        Check to see if array has a given key.
    
        :param: key The key to check for.
        :returns:    Whether the key is present.
    */
    public func has(key: String) -> Bool {
        return find(key) != nil
    }

    /**
        Append one or more objects to the array.
    
        :param: objects The object or objects to add to the array.
    */
    public func append(objects: T...) {
        for o in objects {
            precondition(index[o.key!] == nil, "Cannot append item with existing key: \(o.key!)")
            index[o.key!] = rawArray.count
            rawArray.append(o)
        }
    }

    /**
        Concatenate objects onto the array.

        :param: objects The array of objects to concatenate or extend with.
    */
    public func extend(objects: [T]) {
        for o in objects {
            append(o)
        }
    }
    
    /**
        Insert an object into the array at a given index.  NOTE: O(n)

        :param: object  The object to insert.
        :param: atIndex The index at which to insert the object.
    */
    public func insert(object: T, atIndex: Int) {
        precondition(index[object.key!] == nil, "Cannot insert item with existing key: \(object.key!)")
        rawArray.insert(object, atIndex: atIndex)
        for i in atIndex..<rawArray.count {
            index[rawArray[i].key!] = i
        }
    }
    
    /**
        Remove an object from the array at a given index.  NOTE: O(n)
        
        :param: atIndex The index at which to insert the object.
    */
    public func removeAtIndex(atIndex: Int) {
        let t = rawArray.removeAtIndex(atIndex)
        index.removeValueForKey(t.key!)
        for i in atIndex..<rawArray.count {
            index[rawArray[i].key!] = i
        }
    }
    
    /**
        Reset to initial state.
    */
    public func clear() {
        rawArray = []
        index = [:]
    }
    
    /**
        Update array so its state matches other array.

        :param: other   The other array.
    */
    public func reset(other: KeyedArray<T>) {
        rawArray = other.rawArray
        index = other.index
    }
    
    /**
        Update array so its state matches a raw array.
        
        :param: rawArray   The raw array.
    */
    public func reset(rawArray: [T]) {
        clear()
        extend(rawArray)
    }
}

extension KeyedArray : CollectionType {
    public var count: Int {
        return rawArray.count
    }
    
    public subscript(i: Int) -> T {
        return rawArray[i]
    }
    
    public func generate() -> GeneratorOf<T> {
        var g = rawArray.generate()
        return GeneratorOf<T> {
            return g.next()
        }
    }
    
    public var startIndex: Int {
        return rawArray.startIndex
    }
    
    public var endIndex: Int {
        return rawArray.endIndex
    }
}
