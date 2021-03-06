//
//  UnionStream.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation

/**
    Compose a stream out of other streams.  Some example use cases are:

    - Placeholders
    - Multiple Firebase queries in one view

    It's ok for the keys to overlap, and for different substreams to have different
    types.  The sort order of the first stream is used by the union stream.  (The sort orders 
    of the other streams is ignored.)
*/
public class UnionStream {
    private let sources: [StreamBase]  // TODO StreamBaseProtocol
    private let delegates: [UnionStreamDelegate]
    private var timer: NSTimer?
    private var numStreamsFinished: Int? = 0
    private var union = KeyedArray<BaseItem>()
    private var error: NSError?    
    private var comparator: StreamBase.Comparator {
        get {
            return sources[0].comparator
        }
    }
    
    /**
        The delegate to notify as the merged stream is updated.
    */
    weak public var delegate: StreamBaseDelegate?

    /**
        Construct a union stream from other streams.  The sort order of the first substream
        is used for the union.
    
        :param: sources The substreams.
    */
    public init(sources: StreamBase...) {
        precondition(sources.count > 0)
        self.sources = sources
        delegates = sources.map{ UnionStreamDelegate(source: $0) }
        for (s, d) in zip(sources, delegates) {
            d.union = self
            s.delegate = d
        }
    }
    
    private func update() {
        var newUnion = [BaseItem]()
        var seen = Set<String>()
        for source in sources {
            for item in source {
                if !seen.contains(item.key!) {
                    newUnion.append(item)
                    seen.insert(item.key!)
                }
            }
        }
        
        newUnion.sortInPlace(comparator)
        StreamBase.applyBatch(union, batch: newUnion, delegate: delegate)
        
        if numStreamsFinished == sources.count {
            numStreamsFinished = nil
            delegate?.streamDidFinishInitialLoad(error)
        }
    }
    
    func needsUpdate() {
        timer?.invalidate()
        timer = NSTimer.schedule(delay: 0.1) { [weak self] timer in
            self?.update()
        }
    }
    
    func didFinishInitialLoad(error: NSError?) {
        if let e = error where self.error == nil {
            self.error = e
            // Any additional errors are ignored.
        }
        numStreamsFinished?++
        needsUpdate()
    }
    
    func changed(t: BaseItem) {
        if let row = union.find(t.key!) {
            delegate?.streamItemsChanged([NSIndexPath(forRow: row, inSection: 0)])
        }
    }
    
}

extension UnionStream : Indexable {
    public typealias Index = Int
    
    public var startIndex: Index {
        return union.startIndex
    }
    
    public var endIndex: Index {
        return union.startIndex
    }
    
    public subscript(i: Index) -> BaseItem {
        return union[i]
    }
}

extension UnionStream : CollectionType { }

extension UnionStream : StreamBaseProtocol {
    public func find(key: String) -> BaseItem? {
        if let row = union.find(key) {
            return union[row]
        }
        return nil
    }
    
    public func findIndexPath(key: String) -> NSIndexPath? {
        if let row = union.find(key) {
            return NSIndexPath(forRow: row, inSection: 0)
        }
        return nil
    }
}

private class UnionStreamDelegate: StreamBaseDelegate {
    weak var source: StreamBase?
    weak var union: UnionStream?
    
    init(source: StreamBase) {
        self.source = source
    }
    
    func streamWillChange() {
    }
    
    func streamDidChange() {
        union?.needsUpdate()
    }
    
    func streamItemsAdded(paths: [NSIndexPath]) {
    }
    
    func streamItemsDeleted(paths: [NSIndexPath]) {
    }
    
    func streamItemsChanged(paths: [NSIndexPath]) {
        for path in paths {
            if let t = source?[path.row] {
                union?.changed(t)
            }
        }
    }
    
    func streamDidFinishInitialLoad(error: NSError?) {
        union?.didFinishInitialLoad(error)
    }
}