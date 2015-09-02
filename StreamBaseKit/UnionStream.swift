//
//  UnionStream.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation

public class UnionStream {
    private let sources: [StreamBase]  // TODO switch to StreamBaseProtocol
    private let delegates: [UnionStreamDelegate]
    private var timer: NSTimer?
    private var numStreamsFinished: Int? = 0
    private var union = KeyedArray<StreamBaseItem>()
    weak public var delegate: StreamBaseDelegate?
    
    var comparator: StreamBase.Comparator {
        get {
            return sources[0].comparator
        }
    }
    
    // The sort order of the first source is used.
    public init(sources: [StreamBase]) {
        precondition(sources.count > 0)
        self.sources = sources
        delegates = sources.map{ UnionStreamDelegate(source: $0) }
        for (s, d) in zip(sources, delegates) {
            d.union = self
            s.delegate = d
        }
    }
    
    private func update() {
        var newUnion = [StreamBaseItem]()
        var seen = Set<String>()
        for source in sources {
            for item in source {
                if !seen.contains(item.key!) {
                    newUnion.append(item)
                    seen.insert(item.key!)
                }
            }
        }
        
        sort(&newUnion, comparator)
        StreamBase.applyBatch(union, batch: newUnion, delegate: delegate)
        
        if numStreamsFinished == sources.count {
            numStreamsFinished = nil
            delegate?.streamDidFinishInitialLoad()
        }
    }
    
    func needsUpdate() {
        timer?.invalidate()
        timer = NSTimer.schedule(delay: 0.1) { [weak self] timer in
            self?.update()
        }
    }
    
    func didFinishInitialLoad() {
        numStreamsFinished?++
        needsUpdate()
    }
    
    func changed(t: StreamBaseItem) {
        if let row = union.find(t.key!) {
            delegate?.streamItemsChanged([NSIndexPath(forRow: row, inSection: 0)])
        }
    }
    
}

extension UnionStream : SequenceType {
    public var count: Int {
        return union.count
    }
    
    public subscript(i: Int) -> StreamBaseItem {
        return union[i]
    }
    
    public func generate() -> GeneratorOf<StreamBaseItem> {
        return union.generate()
    }
}

extension UnionStream : StreamBaseProtocol {
    public func find(key: String) -> StreamBaseItem? {
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
    
    func streamDidFinishInitialLoad() {
        union?.didFinishInitialLoad()
    }
}