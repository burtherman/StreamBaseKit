//
//  ResourceContextTests.swift
//  Quorum
//
//  Created by Steve Farrell on 9/10/15.
//  Copyright (c) 2015 Movem3nt. All rights reserved.
//

import Foundation

import XCTest
import StreamBaseKit
import Firebase

class ResourceContextTests: XCTestCase {
    let base = ResourceBase(firebase: Firebase())
    
    let a = BaseItem(key: "a")
    let b = BaseItem(key: "b")
    let b2 = BaseItem(key: "b2")
    let c = BaseItem(key: "c")
    let d = BaseItem(key: "d")
    
    func testEmptyIteration() {
        let rc = ResourceContext(base: base, resources: ResourceDict())
        for (k, v) in rc {
            XCTFail("empty")
        }
    }
    
    func testSingleIteration() {
        let rc = ResourceContext(base: base, resources: ["a": a])
        var expected = Set(arrayLiteral: "a")
        for (k, v) in rc {
            XCTAssertEqual(rc.get(k)!.key!, v.key!)
            XCTAssertNotNil(expected.remove(k))
        }
        XCTAssertTrue(expected.isEmpty)
    }
    
    func testMultiIteration() {
        let rc = ResourceContext(base: base, resources: ["a": a, "b": b])
        var expected = Set(arrayLiteral: "a", "b")
        for (k, v) in rc {
            XCTAssertEqual(rc.get(k)!.key!, v.key!)
            XCTAssertNotNil(expected.remove(k))
        }
        XCTAssertTrue(expected.isEmpty)
    }
    
    func testStackIteration() {
        let rc = ResourceContext(base: base, resources: ["a": a]).push(["b": b]).push(["c": c])
        var expected = Set(arrayLiteral: "a", "b", "c")
        for (k, v) in rc {
            XCTAssertEqual(rc.get(k)!.key!, v.key!)
            XCTAssertNotNil(expected.remove(k))
        }
        XCTAssertTrue(expected.isEmpty)
    }
    
    func testStackIterationWithMasking() {
        let rc = ResourceContext(base: base, resources: ["a": a, "b": b2]).push(["b": b, "c": c]).push(["d": d])
        var expected = Set(arrayLiteral: "a", "b", "c", "d")
        for (k, v) in rc {
            XCTAssertEqual(rc.get(k)!.key!, v.key!)
            XCTAssertNotNil(expected.remove(k))
            XCTAssertNotEqual(b2.key!, v.key!, "b2 is masked")
        }
        XCTAssertTrue(expected.isEmpty)
    }
}