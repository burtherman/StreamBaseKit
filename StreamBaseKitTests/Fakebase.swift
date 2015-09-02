//
//  Fakebase.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import StreamBaseKit
import Firebase

func paths(paths: (Int, Int)...) -> [NSIndexPath] {
    return paths.map { NSIndexPath(forRow: $0.1, inSection: $0.0) }
}

class TestItem : StreamBaseItem {
    static let a = TestItem(key: "a")
    static let b = TestItem(key: "b")
    static let c = TestItem(key: "c")
    static let d = TestItem(key: "d")
    
    var bool: Bool?
    var int: Int?
    var float: Float?
    var string: String?
    
    override var dict: [String: AnyObject] {
        var d = super.dict
        d["bool"] = bool ?? NSNull()
        d["int"] = int ?? NSNull()
        d["float"] = float ?? NSNull()
        d["string"] = string ?? NSNull()
        return d
    }
    
    override func update(dict: [String: AnyObject]) {
        super.update(dict)
        bool = dict["bool"] as? Bool
        int = dict["int"] as? Int
        float = dict["float"] as? Float
        string = dict["string"] as? String
    }
}

class TestDelegate : StreamBaseDelegate {
    var willChangeCount = 0
    var didChangeCount = 0
    var itemAdded = [NSIndexPath]()
    var itemDeleted = [NSIndexPath]()
    var itemChanged = [NSIndexPath]()
    
    func streamWillChange() {
        willChangeCount++
        itemAdded = []
        itemDeleted = []
        itemChanged = []
    }
    func streamDidChange() {
        didChangeCount++
    }
    func streamItemsAdded(paths: [NSIndexPath]) {
        itemAdded.extend(paths)
    }
    func streamItemsDeleted(paths: [NSIndexPath]) {
        itemDeleted.extend(paths)
    }
    func streamItemsChanged(paths: [NSIndexPath]) {
        itemChanged.extend(paths)
    }
    func streamDidFinishInitialLoad(error: NSError?) {
    }
}

class FakeFQuery : FQuery {
    let fakebase: Fakebase
    
    init(fakebase: Fakebase) {
        self.fakebase = fakebase
    }
    
    override func observeEventType(eventType: FEventType, withBlock block: ((FDataSnapshot!) -> Void)!) -> UInt {
        fakebase.handlers[eventType] = block
        return UInt(fakebase.handlers.count)
    }
}

class FakeSnapshot : FDataSnapshot {
    let k: String
    let v: [String: AnyObject]
    
    override var key: String {
        return k
    }
    
    override var value: AnyObject {
        return v
    }
        
    init(key: String, value: [String: AnyObject] = [:]) {
        self.k = key
        self.v = value
    }
}

class Fakebase : Firebase {
    typealias Handler = ((FDataSnapshot!) -> Void)
    var handlers = [FEventType: Handler]()
    var fakeKey: String?
    
    override var key: String? {
        return fakeKey
    }
    
    convenience override init() {
        self.init(fakeKey: nil)
    }
    
    init(fakeKey: String?) {
        super.init()
        self.fakeKey = fakeKey
    }
    
    override func childByAppendingPath(pathString: String!) -> Firebase! {
        assert(pathString.rangeOfString("/") == nil, "Cannot handle paths")
        return Fakebase(fakeKey: pathString)
    }
    
    override func queryLimitedToLast(limit: UInt) -> FQuery! {
        return FakeFQuery(fakebase: self)
    }
    
    override func queryOrderedByKey() -> FQuery! {
        return FakeFQuery(fakebase: self)
    }
    
    override func observeEventType(eventType: FEventType, withBlock block: ((FDataSnapshot!) -> Void)!) -> UInt {
        handlers[eventType] = block
        return UInt(handlers.count)
    }
    
    func add(snap: FDataSnapshot) {
        handlers[.ChildAdded]!(snap)
    }
    
    func remove(snap: FDataSnapshot) {
        handlers[.ChildRemoved]!(snap)
    }
    
    func change(snap: FDataSnapshot) {
        handlers[.ChildChanged]!(snap)
    }
}