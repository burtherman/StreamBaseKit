//
//  StreamBaseProtocol.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/3/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation

/**
    Common interface among several stream-like things including StreamBase, UnionStream,
    TransientStream, and PartitionedStream.

    NOTE: This protocol is under-used because what I think are Swift 1.2 limitations.  For
    example, if this protocol extends SequenceType (as it should), then it can not be
    used as the type of an instance variable.
*/
public protocol StreamBaseProtocol: class {
    /**
        A delegate to notify when the stream changes.
    */
    var delegate: StreamBaseDelegate? { get set }
    
    /**
        Find the item with the given key.
        
        :param: key The key to look up.
        :returns:   The item matching the key.
    */
    func find(key: String) -> BaseItem?
    
    /**
        Find the path of the item with the given key.
        
        :param: key The key to look up.
        :returns:   The path of the item matching the key.
    */
    func findIndexPath(key: String) -> NSIndexPath?
}
