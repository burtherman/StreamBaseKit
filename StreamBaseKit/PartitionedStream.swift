//
//  PartitionedStream.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/20/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//
//  NOTE: With current implementation, deletes and moves are O(n).  
//  Adding unordered stuff one item at a time is O(n*m).

import Foundation

public class PartitionedStream {
    public typealias Partitioner = StreamBaseItem -> Int
    
    public weak var delegate: StreamBaseDelegate?
    
    public let numSections : Int
    public let sectionTitles : [String]
    
    private let stream : StreamBase
    private var sections = [[StreamBaseItem]]()
    private let partitioner : Partitioner
    private var map = [NSIndexPath]()
    
    public var mapForTesting: [NSIndexPath] {
        get {
            return map
        }
    }
    
    public init(stream: StreamBase, sectionTitles: [String], partitioner: Partitioner) {
        self.stream = stream
        self.sectionTitles = sectionTitles
        self.numSections = sectionTitles.count
        self.partitioner = partitioner
        self.stream.delegate = self
        for i in 0..<numSections {
            sections.append([])
        }
    }
    
    public subscript(index: NSIndexPath) -> StreamBaseItem {
        return sections[index.section][index.row]
    }

    public subscript(section: Int, row: Int) -> StreamBaseItem {
        return sections[section][row]
    }
    
    public subscript(section: Int) -> [StreamBaseItem] {
        return sections[section]
    }
    
    private func add(section: Int, obj: StreamBaseItem, streamIndex: Int, inout addedPaths: [NSIndexPath]) {
        if sections[section].count == 0 || stream.comparator(sections[section].last!, obj) {
            // append
            addedPaths.append(NSIndexPath(forRow: sections[section].count, inSection: section))
            sections[section].append(obj)
        } else {
            // insert - hopefully rare!
            let prev = sections[section]
            sections[section] = []
            var inserted = false
            for p in prev {
                if !inserted && stream.comparator(obj, p)  {
                    addedPaths.append(NSIndexPath(forRow: sections[section].count, inSection: section))
                    sections[section].append(obj)
                    inserted = true
                }
                sections[section].append(p)
            }
            assert(inserted)
        }
        
        let mappedPath = addedPaths.last!
        if streamIndex == map.count {
            map.append(mappedPath)
        } else {
            map.splice([mappedPath], atIndex: streamIndex)
            for i in streamIndex+1..<map.count {
                if map[i].section == mappedPath.section {
                    let moved = NSIndexPath(forRow: map[i].row + 1, inSection: map[i].section)
                    map[i] = moved
                }
            }
        }
    }
    
    private func delete(streamIndex: Int, inout deletedPaths: [NSIndexPath]) {
        let delPath = map.removeAtIndex(streamIndex)
        for i in streamIndex..<map.count {
            if map[i].section == delPath.section {
                let moved = NSIndexPath(forRow: map[i].row - 1, inSection: map[i].section)
                map[i] = moved
            }
        }
        sections[delPath.section].removeAtIndex(delPath.row)
        deletedPaths.append(delPath)
    }
}

extension PartitionedStream : SequenceType {
    public var count: Int {
        return stream.count
    }
    
    public subscript(i: Int) -> StreamBaseItem {
        return stream[i]
    }
    
    public func generate() -> GeneratorOf<StreamBaseItem> {
        return stream.generate()
    }
}

extension PartitionedStream : StreamBaseProtocol {
    public func find(key: String) -> StreamBaseItem? {
        return stream.find(key)
    }
    
    public func findIndexPath(key: String) -> NSIndexPath? {
        if let path = stream.findIndexPath(key) {
            return map[path.row]
        }
        return nil
    }
}

extension PartitionedStream : StreamBaseDelegate {
    public func streamWillChange() {
        delegate?.streamWillChange()
    }
    
    public func streamDidChange() {
        delegate?.streamDidChange()
    }
    
    public func streamItemsAdded(paths: [NSIndexPath]) {
        var addedPaths = [NSIndexPath]()
        for path in paths {
            let obj = stream[path.row]
            let section = partitioner(obj)
            add(section, obj: obj, streamIndex: path.row, addedPaths: &addedPaths)
        }
        delegate?.streamItemsAdded(addedPaths)
    }
    
    public func streamItemsDeleted(paths: [NSIndexPath]) {
        var deletedPaths = [NSIndexPath]()
        for path in paths {
            delete(path.row, deletedPaths: &deletedPaths)
        }
        delegate?.streamItemsDeleted(deletedPaths)
    }
    
    public func streamItemsChanged(paths: [NSIndexPath]) {
        var changedPaths = [NSIndexPath]()
        var addedPaths = [NSIndexPath]()
        var deletedPaths = [NSIndexPath]()
        for path in paths {
            let curPath = map[path.row]
            let obj = stream[path.row]
            let section = partitioner(obj)
            if curPath.section == section {
                changedPaths.append(curPath)
            } else {
                delete(path.row, deletedPaths: &deletedPaths)
                add(section, obj: obj, streamIndex: path.row, addedPaths: &addedPaths)
            }
        }
        assert(addedPaths.count == deletedPaths.count, "\(addedPaths.count) <> \(deletedPaths.count)")
        
        if !changedPaths.isEmpty {
            delegate?.streamItemsChanged(changedPaths)
        }
        if !addedPaths.isEmpty || !deletedPaths.isEmpty {
            delegate?.streamWillChange()
        }
        if !addedPaths.isEmpty {
            delegate?.streamItemsAdded(addedPaths)
        }
        if !deletedPaths.isEmpty {
            delegate?.streamItemsDeleted(deletedPaths)
        }
        if !addedPaths.isEmpty || !deletedPaths.isEmpty {
            delegate?.streamDidChange()
        }
    }
    
    public func streamDidFinishInitialLoad() {
        delegate?.streamDidFinishInitialLoad()
    }
}