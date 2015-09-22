//
//  NSTimer+Closure.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//
//  Based on https://gist.github.com/natecook1000/b0285b518576b22c4dc8

import Foundation

extension NSTimer {
    /**
        Creates and schedules a one-time `NSTimer` instance.
        
        :param: delay The delay before execution.
        :param: handler A closure to execute after `delay`.
        
        :returns: The newly-created `NSTimer` instance.
    */
    class func schedule(delay delay: NSTimeInterval, handler: NSTimer! -> Void) -> NSTimer {
        let fireDate = delay + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, handler)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes)
        return timer
    }
    
    /**
        Creates and schedules a repeating `NSTimer` instance.
        
        :param: repeatInterval The interval between each execution of `handler`. Note that individual calls may be delayed; subsequent calls to `handler` will be based on the time the `NSTimer` was created.
        :param: handler A closure to execute after `delay`.
        
        :returns: The newly-created `NSTimer` instance.
    */
    class func schedule(repeatInterval interval: NSTimeInterval, handler: NSTimer! -> Void) -> NSTimer {
        let fireDate = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, interval, 0, 0, handler)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes)
        return timer
    }
}
