//
//  KeyedArray.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Steve Farrell and Movem3nt, Inc. All rights reserved.
//
//  A Collection that wraps both an array and dictionary.  It has O(1) access
//  by index or key and for appends, but is O(n) for inserts and deletes.

import Foundation

public protocol KeyedObject: class {
    var key: String? { get }
}

public class KeyedArray<T: KeyedObject> : CollectionType {
    public var rawArray = [T]()  // TODO shouldn't be public
    private var index = [String: Int]()
    
    public init() { }
    
    public init(rawArray: [T]) {
        for t in rawArray {
            append(t)
        }
    }
    
    public func find(key: String) -> Int? {
        if let i = index[key] {
            return i
        }
        return nil
    }
    
    public func has(key: String) -> Bool {
        return find(key) != nil
    }
    
    // TODO: replace with findPrevious(key)/findNext(key) that depends on the existing
    // ordering.
    public func findFirstWhere(predicate: T -> Bool) -> Int? {
        if rawArray.isEmpty {
            return nil
        }
        
        var left = rawArray.startIndex
        var right = rawArray.endIndex - 1
        
        if predicate(rawArray.first!) {
            return left
        }
        
        var midpoint = rawArray.count / 2
        while right - left > 1 {
            if predicate(rawArray[midpoint]) {
                right = midpoint
            } else {
                left = midpoint
            }
            midpoint = (left + right) / 2
        }
        return predicate(rawArray[left]) ? left : (predicate(rawArray[right]) ? right : nil)
    }
    
    public func findLastWhere(predicate: T -> Bool) -> Int? {
        if rawArray.isEmpty {
            return nil
        }
        
        var left = rawArray.startIndex
        var right = rawArray.endIndex - 1
        
        if predicate(rawArray.last!) {
            return right
        }
        
        var midpoint = rawArray.count / 2
        while right - left > 1 {
            if predicate(rawArray[midpoint]) {
                left = midpoint
            } else {
                right = midpoint
            }
            midpoint = (left + right) / 2
        }
        return predicate(rawArray[right]) ? right : (predicate(rawArray[left]) ? left : nil)
    }
    
    public func append(t: T) {
        precondition(index[t.key!] == nil, "Cannot append item with existing key: \(t.key!)")
        index[t.key!] = rawArray.count
        rawArray.append(t)
    }
    
    public func extend(ts: [T]) {
        for t in ts {
            append(t)
        }
    }
    
    // NOTE: O(n)
    public func insert(t: T, atIndex: Int) {
        precondition(index[t.key!] == nil, "Cannot insert item with existing key: \(t.key!)")
        rawArray.insert(t, atIndex: atIndex)
        for i in atIndex..<rawArray.count {
            index[rawArray[i].key!] = i
        }
    }
    
    // NOTE: O(n)
    public func removeAtIndex(atIndex: Int) {
        let t = rawArray.removeAtIndex(atIndex)
        index.removeValueForKey(t.key!)
        for i in atIndex..<rawArray.count {
            index[rawArray[i].key!] = i
        }
    }
    
    public func clear() {
        rawArray = []
        index = [:]
    }
    
    public func reset(keyedArray: KeyedArray<T>) {
        reset(keyedArray.rawArray)
    }
    
    public func reset(rawArray: [T]) {
        clear()
        for t in rawArray {
            append(t)
        }
    }
    
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
