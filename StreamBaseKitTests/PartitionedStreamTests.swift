//
//  PartitionedStreamTests.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/20/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import XCTest
import StreamBaseKit

class PartitionedStreamTests: XCTestCase {
    
    var ref: Fakebase!
    var stream: StreamBase!
    let snapA = FakeSnapshot(key: TestItem.a.key!, value: ["int": 1])
    let snapB = FakeSnapshot(key: TestItem.b.key!, value: ["int": 2])
    let snapB2 = FakeSnapshot(key: TestItem.b.key!, value: ["int": 0])
    let snapC = FakeSnapshot(key: TestItem.c.key!, value: ["int": 3])
    
    override func setUp() {
        super.setUp()
        ref = Fakebase()
        stream = StreamBase(type: TestItem.self, ref: ref)
        stream.batchDelay = nil
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func verifyMap(pstream: PartitionedStream) {
        var revMap = [NSIndexPath: Int]()
        for (i, p) in enumerate(pstream.mapForTesting) {
            revMap[p] = i
            XCTAssertEqual(stream[i].key!, pstream[p].key!)
        }
        for s in 0..<pstream.numSections {
            for r in 0..<pstream[s].count {
                if let i = revMap[NSIndexPath(forRow: r, inSection: s)] {
                    XCTAssertEqual(stream[i].key!, pstream[s, r].key!)
                } else {
                    XCTFail("\(s)/\(r) -> \(pstream[s, r].key!) MISSING")
                }
            }
        }
    }
    
    func dumpMap(pstream: PartitionedStream) {
        var revMap = [NSIndexPath: Int]()
        for (i, p) in enumerate(pstream.mapForTesting) {
            if i < stream.count {
                println("F: \(i): \(p.section)/\(p.row) -> \(stream[i].key!)")
            } else {
                println("F: \(i): \(p.section)/\(p.row) -> MISSING")
            }
            revMap[p] = i
        }

        for s in 0..<pstream.numSections {
            for r in 0..<pstream[s].count {
                if let i = revMap[NSIndexPath(forRow: r, inSection: s)] {
                    println("R: \(s)/\(r): \(i) -> \(pstream[s, r].key!) == \(stream[i].key!)")
                } else {
                    println("R: \(s)/\(r): -> \(pstream[s, r].key!) MISSING")
                }
            }
        }
    }
    
    func testDefaultPartitioner() {
        let delegate = TestDelegate()
        let pstream = PartitionedStream(stream: stream, sectionTitles: [""], partitioner: { _ in return 0 })
        pstream.delegate = delegate
        ref.add(snapA)
        XCTAssertEqual(paths((0, 0)), delegate.itemAdded)
        XCTAssertEqual([], delegate.itemDeleted)
        XCTAssertEqual([], delegate.itemChanged)
        verifyMap(pstream)
    }

    func testBiPartitioner() {
        let delegate = TestDelegate()
        let pstream = PartitionedStream(stream: stream, sectionTitles: ["", ""], partitioner: { $0.key < self.snapB.key ? 0 : 1 })
        pstream.delegate = delegate
        ref.add(snapA)
        XCTAssertEqual(paths((0,0)), delegate.itemAdded)
        ref.add(snapB)
        XCTAssertEqual(paths((1,0)), delegate.itemAdded)
        ref.add(snapC)
        XCTAssertEqual(paths((1,1)), delegate.itemAdded)
        XCTAssertEqual([], delegate.itemDeleted)
        XCTAssertEqual([], delegate.itemChanged)
        XCTAssertEqual([snapA.key, snapB.key, snapC.key], [pstream[0, 0].key!, pstream[1, 0].key!, pstream[1, 1].key!])
        verifyMap(pstream)
    }

    func testBiPartitionerReversed() {
        let delegate = TestDelegate()
        let pstream = PartitionedStream(stream: stream, sectionTitles: ["", ""], partitioner: { $0.key < self.snapB.key ? 0 : 1 })
        pstream.delegate = delegate
        ref.add(snapC)
        XCTAssertEqual(paths((1,0)), delegate.itemAdded)
        XCTAssertEqual(snapC.key, pstream[1, 0].key!)

        ref.add(snapB)
        XCTAssertEqual(paths((1,0)), delegate.itemAdded)
        XCTAssertEqual(snapB.key, pstream[1, 0].key!)
        XCTAssertEqual(snapC.key, pstream[1, 1].key!)

        ref.add(snapA)
        XCTAssertEqual(paths((0,0)), delegate.itemAdded)
        XCTAssertEqual([], delegate.itemDeleted)
        XCTAssertEqual([], delegate.itemChanged)
        XCTAssertEqual([snapA.key, snapB.key, snapC.key], [pstream[0, 0].key!, pstream[1, 0].key!, pstream[1, 1].key!])
        dumpMap(pstream)
        verifyMap(pstream)
    }

    func testBiPartitionerDeletes() {
        let delegate = TestDelegate()
        let pstream = PartitionedStream(stream: stream, sectionTitles: ["", ""], partitioner: { $0.key < self.snapB.key ? 0 : 1 })
        pstream.delegate = delegate
        ref.add(snapA)
        ref.add(snapB)
        ref.add(snapC)
        XCTAssertEqual([snapA.key, snapB.key, snapC.key], [pstream[0, 0].key!, pstream[1, 0].key!, pstream[1, 1].key!])
        ref.remove(snapB)
        XCTAssertEqual(paths((1, 0)), delegate.itemDeleted)
        XCTAssertEqual([snapA.key, snapC.key], [pstream[0, 0].key!, pstream[1, 0].key!])
        verifyMap(pstream)
    }

    func testBiPartitionerChanges() {
        let delegate = TestDelegate()
        let pstream = PartitionedStream(stream: stream, sectionTitles: ["", ""], partitioner: { ($0 as! TestItem).int < 2 ? 0 : 1 })
        pstream.delegate = delegate
        ref.add(snapA)
        ref.add(snapB)
        ref.add(snapC)
        XCTAssertEqual([snapA.key, snapB.key, snapC.key], [pstream[0, 0].key!, pstream[1, 0].key!, pstream[1, 1].key!])
        
        ref.change(snapB)
        XCTAssertEqual(paths((1, 0)), delegate.itemChanged)
        
        ref.change(snapB2)
        XCTAssertEqual(1, delegate.itemDeleted.count)
        XCTAssertEqual(1, delegate.itemAdded.count)
        XCTAssertEqual(paths((1, 0)), delegate.itemDeleted)
        XCTAssertEqual(paths((0, 1)), delegate.itemAdded)
        XCTAssertEqual([snapA.key, snapB.key, snapC.key], [pstream[0, 0].key!, pstream[0, 1].key!, pstream[1, 0].key!])

        verifyMap(pstream)
    }
    
    func testMixedAddsDeletesChanges() {
        let pstream = PartitionedStream(stream: stream, sectionTitles: ["", "", "", "", "", ""]) { item in
            let testItem = item as! TestItem
            if testItem.int > 0 {
                return 4
            }
            switch testItem.key! {
            case "a", "e", "i", "o", "u": return 0
            case "A", "E", "I", "O", "U": return 1
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9": return 2
            default: return 3
            }
        }
        let keys = Array("abcdefghijklmnopqrstuvwxyz9876543210ABCDEFGHIJKLMNOPQRSTUVWXYZ").map{ String($0) }
        for key in keys {
            let snap = FakeSnapshot(key: key, value: [:])
            ref.add(snap)
        }
        verifyMap(pstream)
        
        for key in ["a", "A", "3", "2", "1"] {
            let snap = FakeSnapshot(key: key, value: [:])
            ref.remove(snap)
        }
        verifyMap(pstream)

        for key in ["x", "y", "z", "9", "Z"] {
            let snap = FakeSnapshot(key: key, value: ["value": 1])
            ref.change(snap)
        }
        verifyMap(pstream)
    }
}
