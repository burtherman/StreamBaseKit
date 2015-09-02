//
//  Inflight.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 4/30/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//
//  RAII interface for network activity indicator: simply keep an Inflight object
//  in scope for the duration of the request.  As long as you're not leaking Inflight
//  objects, the underlying counter will remain accurate.  There are a few ways to make
//  sure this works with closures.  I recommend this pattern:
//
//  var inflight : Inflight? = Inflight()
//  doSomethingInBackground() { 
//    inflight = nil
//  }

import UIKit


private class InflightManager {
    private static let sharedManager = InflightManager()
    
    var counter: UnsafeMutablePointer<Int32>
    init() {
        counter = UnsafeMutablePointer<Int32>.alloc(1)
        counter.initialize(0)
    }
    
    deinit {
        counter.dealloc(1)
    }
    
    func increment() {
        OSAtomicIncrement32(counter)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    func decrement() {
        let newValue = OSAtomicDecrement32(counter)
        assert(newValue >= 0)
        if newValue == 0 {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
}

class Inflight {

    init() {
        InflightManager.sharedManager.increment()
    }
    
    deinit {
        InflightManager.sharedManager.decrement()
    }
}