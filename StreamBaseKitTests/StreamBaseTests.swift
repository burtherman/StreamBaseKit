//
//  StreamBaseTests.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import UIKit
import XCTest
import StreamBaseKit

class StreamBaseTests: XCTestCase {
    var ref: Fakebase!
    var stream: StreamBase!
    var delegate: TestDelegate!
    let snapA = FakeSnapshot(key: TestItem.a.key!)
    let snapB = FakeSnapshot(key: TestItem.b.key!)
    let snapC = FakeSnapshot(key: TestItem.c.key!)
    
    override func setUp() {
        super.setUp()
        ref = Fakebase()
        stream = StreamBase(type: TestItem.self, ref: ref)
        stream.batchDelay = nil
        delegate = TestDelegate()
        stream.delegate = delegate
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testStreamBaseAdd() {
        ref.add(snapA)
        XCTAssertEqual(1, delegate.willChangeCount)
        XCTAssertEqual(0, delegate.itemAdded[0].row)
        XCTAssertEqual(TestItem.a, stream[0])
    }
    
    func testStreamBaseRemove() {
        // First, check that it's a no-op, because the TestItem removed didn't exist
        ref.remove(snapA)
        XCTAssertEqual(0, delegate.willChangeCount)
        
        // Next, add and remove.
        ref.add(snapA)
        XCTAssertEqual(1, delegate.willChangeCount)
        XCTAssertEqual(0, delegate.itemAdded[0].row)
        XCTAssertEqual(TestItem.a, stream[0])
        
        ref.remove(snapA)
        XCTAssertEqual(2, delegate.willChangeCount)
        XCTAssertEqual(0, stream.count)
    }
    
    func testStreamBasePredicateAdd() {
        stream.predicate = { $0.key != TestItem.a.key }
        ref.add(snapA)
        ref.add(snapB)
        ref.add(snapC)
        XCTAssertEqual(2, delegate.willChangeCount)
        XCTAssertEqual(TestItem.b, stream[0])
        XCTAssertEqual(TestItem.c, stream[1])
    }
    
    func testStreamBasePredicateAddAndRemoveFiltered() {
        testStreamBasePredicateAdd()
        XCTAssertEqual(2, stream.count)
        ref.remove(snapA)
        XCTAssertEqual(2, stream.count)
        stream.predicate = { $0.key == TestItem.a.key }
        XCTAssertEqual(3, delegate.willChangeCount)
        XCTAssertEqual(0, stream.count)
        XCTAssertEqual(0, delegate.itemDeleted[0].row)
        XCTAssertEqual(1, delegate.itemDeleted[1].row)
        stream.predicate = { $0.key != TestItem.a.key }
        XCTAssertEqual(4, delegate.willChangeCount)
        XCTAssertEqual(2, stream.count)
        XCTAssertEqual(0, delegate.itemAdded[0].row)
        XCTAssertEqual(1, delegate.itemAdded[1].row)
    }
    
    func testKeyComparator() {
        XCTAssertTrue(stream.comparator(TestItem.a, TestItem.b))
        XCTAssertFalse(stream.comparator(TestItem.c, TestItem.b))
    }
    
    func testBoolValueComparator() {
        let str = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: true, ordering: .Child("bool"))
        let rev = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: false, ordering: .Child("bool"))
        let ai = TestItem.a.clone() as! TestItem
        let bi = TestItem.b.clone() as! TestItem
        let ci = TestItem.c.clone() as! TestItem
        let di = TestItem.d.clone() as! TestItem
        ai.update(["bool": false])
        bi.update(["bool": true])
        ci.update(["bool": false])
        di.update(["bool": "X"])
        
        for (a, b) in [(TestItem.a, TestItem.b), (ai, bi), (ci, bi), (TestItem.a, di), (di, ai), (di, bi), (di, ci)] {
            XCTAssertTrue(str.comparator(a, b), "\(a.key!) < \(b.key!)")
            XCTAssertFalse(rev.comparator(a, b), "\(a.key!) < \(b.key!)")
        }
    }
    func testIntValueComparator() {
        let str = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: true, ordering: .Child("int"))
        let rev = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: false, ordering: .Child("int"))
        let ai = TestItem.a.clone() as! TestItem
        let bi = TestItem.b.clone() as! TestItem
        let ci = TestItem.c.clone() as! TestItem
        let di = TestItem.d.clone() as! TestItem
        ai.update(["int": 1])
        bi.update(["int": 2])
        ci.update(["int": 1])
        di.update(["int": "X"])
        
        for (a, b) in [(TestItem.a, TestItem.b), (ai, bi), (ci, bi), (TestItem.a, di), (di, ai), (di, bi), (di, ci)] {
            XCTAssertTrue(str.comparator(a, b), "\(a.key!) < \(b.key!)")
            XCTAssertFalse(rev.comparator(a, b), "\(a.key!) < \(b.key!)")
        }
    }
    
    func testFloatValueComparator() {
        let str = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: true, ordering: .Child("float"))
        let rev = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: false, ordering: .Child("float"))
        let ai = TestItem.a.clone() as! TestItem
        let bi = TestItem.b.clone() as! TestItem
        let ci = TestItem.c.clone() as! TestItem
        let di = TestItem.d.clone() as! TestItem
        ai.update(["float": 0.1])
        bi.update(["float": 0.2])
        ci.update(["float": 0.1])
        di.update(["float": "X"])
        
        for (a, b) in [(TestItem.a, TestItem.b), (ai, bi), (ci, bi), (TestItem.a, di), (di, ai), (di, bi), (di, ci)] {
            XCTAssertTrue(str.comparator(a, b), "\(a.key!) < \(b.key!)")
            XCTAssertFalse(rev.comparator(a, b), "\(a.key!) < \(b.key!)")
        }
    }
    
    func testStringValueComparator() {
        let str = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: true, ordering: .Child("string"))
        let rev = StreamBase(type: TestItem.self, ref: ref, limit: nil, ascending: false, ordering: .Child("string"))
        let ai = TestItem.a.clone() as! TestItem
        let bi = TestItem.b.clone() as! TestItem
        let ci = TestItem.c.clone() as! TestItem
        let di = TestItem.d.clone() as! TestItem
        ai.update(["string": "A"])
        bi.update(["string": "B"])
        ci.update(["string": "A"])
        di.update(["string": false])
        
        for (a, b) in [(TestItem.a, TestItem.b), (ai, bi), (ci, bi), (TestItem.a, di), (di, ai), (di, bi), (di, ci)] {
            XCTAssertTrue(str.comparator(a, b), "\(a.key!) < \(b.key!)")
            XCTAssertFalse(rev.comparator(a, b), "\(a.key!) < \(b.key!)")
        }
    }
    
    func testFindFirstLastWithEmptyArray() {
        XCTAssertEqual(0, stream.count)
        XCTAssertNil(stream.findLastIndexPathBefore(TestItem(key: "-")))
        XCTAssertNil(stream.findFirstIndexPathAfter(TestItem(key: "-")))
    }
    
    func testFindFirstWithFullArray() {
        for i in 0..<100 {
            ref.add(FakeSnapshot(key: String(format: "%02d", i)))
        }
        XCTAssertEqual(100, stream.count)
        
        XCTAssertEqual(0, stream.findFirstIndexPathAfter(TestItem(key: "-"))!.row)
        XCTAssertEqual(0, stream.findFirstIndexPathAfter(TestItem(key: "0-"))!.row)
        XCTAssertEqual(2, stream.findFirstIndexPathAfter(TestItem(key: "01-"))!.row)
        XCTAssertEqual(11, stream.findFirstIndexPathAfter(TestItem(key: "10-"))!.row)
        XCTAssertEqual(21, stream.findFirstIndexPathAfter(TestItem(key: "20-"))!.row)
        XCTAssertNil(stream.findFirstIndexPathAfter(TestItem(key: "~")))
    }
    
    func testFindLastWithFullArray() {
        for i in 0..<100 {
            ref.add(FakeSnapshot(key: String(format: "%02d", i)))
        }
        XCTAssertEqual(100, stream.count)
        
        XCTAssertNil(stream.findLastIndexPathBefore(TestItem(key: "-")))
        XCTAssertNil(stream.findLastIndexPathBefore(TestItem(key: "0-")))
        XCTAssertEqual(1, stream.findLastIndexPathBefore(TestItem(key: "01-"))!.row)
        XCTAssertEqual(10, stream.findLastIndexPathBefore(TestItem(key: "10-"))!.row)
        XCTAssertEqual(20, stream.findLastIndexPathBefore(TestItem(key: "20-"))!.row)
        XCTAssertEqual(99, stream.findLastIndexPathBefore(TestItem(key: "~"))!.row)
    }

}