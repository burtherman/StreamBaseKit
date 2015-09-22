//
//  StreamBase.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Firebase

/**
    Surfaces a Firebase collection as a stream suitable for presenting in a ui table or 
    collection.
    
    In addition to basic functionality of keeping stream synched with Firebase backing store
    and invoking a delegate with updates, it has some more advanced features:
    
    * Inverted streams
    * Paging
    * Predicates
    * Batching
*/
public class StreamBase : StreamBaseProtocol {
    public typealias Predicate = BaseItem -> Bool
    public typealias Comparator = (BaseItem, BaseItem) -> Bool
    public typealias QueryPager = (start: AnyObject?, end: AnyObject?, limit: Int?) -> FQuery

    public enum Ordering {
        case Key
        case Child(String)
        // TODO Priority
    }
    
    private var handles = [UInt]()
    private var arrayBeforePredicate = KeyedArray<BaseItem>()
    private var array = KeyedArray<BaseItem>()
    private var batchArray = KeyedArray<BaseItem>()
    
    private let type: BaseItem.Type!
    private let query: FQuery!
    private let queryPager: QueryPager!
    private let limit: Int?
    
    private var isBatching = false
    private var timer: NSTimer?
    private var isFetchingMore = false
    private var shouldTellDelegateInitialLoadIsDone: Bool? = false
    
    /**
        The comparator function used for sorting items.
    */
    public let comparator: Comparator
    
    /**
        How long to wait for a batch of changes to accumulate before invoking delegate.
        If nil, then there is no delay.  The unit is seconds.
    */
    public var batchDelay: NSTimeInterval? = 0.1
    
    /**
        A value used to decide whether elements are members of the stream or not.  This
        predicate is evaluated client-side, and so scalability and under-fetching must
        be taken into account.
    */
    public var predicate: Predicate? {
        didSet {
            batching { a in
                if let p = self.predicate {
                    a.clear()
                    for t in self.arrayBeforePredicate {
                        if p(t) {
                            a.append(t)
                        }
                    }
                } else {
                    a.reset(self.arrayBeforePredicate)
                }
            }
        }
    }
    
    /**
        Limit the results after predicate to this value.  If the fetch limit is combined with
        a predicate, then under-fetching may result.
    */
    public var afterPredicateLimit: Int?
    
    /**
        The delegate to notify as the underying data changes.
    */
    public weak var delegate: StreamBaseDelegate? {
        didSet {
            if limit == 0 {
                delegate?.streamDidFinishInitialLoad(nil)
            }
        }
    }

    /**
        Construct an empty stream instance, not connected to any backing Firebase store.
    */
    public init() {
        type = nil
        limit = 0
        query = nil
        queryPager = nil
        comparator = { $0.key < $1.key }
    }
    
    /**
        Construct a stream instance containing items of the given type at the given Firebase reference.

        :param: type    The type of items in the stream.
        :param: ref The Firebase reference where the items are stored.
        :param: limit   The max number to fetch.
        :param: ascending   Whether to materialize the underlying array in ascending or descending order.
        :param: ordering    The ordering to use.
    */
    public convenience init(type: BaseItem.Type, ref: Firebase, limit: Int? = nil, ascending: Bool = true, ordering: Ordering = .Key) {
        let queryBuilder = QueryBuilder(ref: ref)
        queryBuilder.limit = limit
        queryBuilder.ascending = ascending
        queryBuilder.ordering = ordering
        self.init(type: type, queryBuilder: queryBuilder)
    }
    
    /**
        Construct a stream instance containing items of the given type using the query builder specification.
        
        :param: type    The type of items in the stream.
        :param: queryBuilder    The details of what firebase data to query.
    */
    public init(type: BaseItem.Type, queryBuilder: QueryBuilder) {
        self.type = type
        
        limit = queryBuilder.limit
        comparator = queryBuilder.buildComparator()
        query = queryBuilder.buildQuery()
        queryPager = queryBuilder.buildQueryPager()
        
        handles.append(query.observeEventType(.ChildAdded, withBlock: { [weak self] snapshot in
            if let s = self {
                let item = s.type.init(key: snapshot.key)
                item.update(snapshot.value as? [String: AnyObject])
                s.didConstructItem(item)
                s.arrayBeforePredicate.append(item)
                if s.predicate == nil || s.predicate!(item) {
                    s.batching { $0.append(item) }
                }
            }
            }))
        
        handles.append(query.observeEventType(.ChildRemoved, withBlock: { [weak self] snapshot in
            if let s = self {
                if let row = s.arrayBeforePredicate.find(snapshot.key) {
                    s.arrayBeforePredicate.removeAtIndex(row)
                }
                s.batching { a in
                    if let row = a.find(snapshot.key) {
                        a.removeAtIndex(row)
                    }
                }
            }
            }))
        
        handles.append(query.observeEventType(.ChildChanged, withBlock: { [weak self] snapshot in
            if let s = self {
                if let row = s.arrayBeforePredicate.find(snapshot.key) {
                    let t = s.arrayBeforePredicate[row]
                    t.update(snapshot.value as? [String: AnyObject])
                    s.handleItemChanged(t)
                }
            }
            }))
        
        let inflight = Inflight()
        query.observeSingleEventOfType(.Value, withBlock: { [weak self] snapshot in
            if let s = self {
                inflight.hold()
                s.shouldTellDelegateInitialLoadIsDone = true
                s.scheduleBatch()
            }
            }, withCancelBlock: { [weak self] error in
                self?.delegate?.streamDidFinishInitialLoad(error)
            })
    }
    
    deinit {
        for h in handles {
            query.removeObserverWithHandle(h)
        }
    }
    
    /**
        Hook for additional initialization after an item in the stream is created.
    
        :param: item    The item that was just constructed.
    */
    public func didConstructItem(item: BaseItem) {
    }
    
    /**
        Find the item for a given key.
    
        :param: key The key to check
    
        :returns:    The item or nil if not found.
    */
    public func find(key: String) -> BaseItem? {
        if let row = array.find(key) {
            return array[row]
        }
        return nil
    }
    
    /**
        Find the index path for the given key.

        :param: key The key to check.
    
        :returns:    The index path or nil if not found.
    */
    public func findIndexPath(key: String) -> NSIndexPath? {
        if let row = array.find(key) {
            return pathAt(row)
        }
        return nil
    }
    
    /**
        Find the path of the first item that would appear in the stream after the
        exemplar item.  The exemplar item need not be in this stream.
    
        :param: item    The exemplar item.
    
        :returns:   The index path of that first item or nil if none is found.
    */
    public func findFirstIndexPathAfter(item: BaseItem) -> NSIndexPath? {
        let a = array.rawArray
        if a.isEmpty {
            return nil
        }
        
        let predicate = { self.comparator(item, $0) }
        var left = a.startIndex
        var right = a.endIndex - 1
        
        if predicate(a.first!) {
            return pathAt(left)
        }
        
        var midpoint = a.count / 2
        while right - left > 1 {
            if predicate(a[midpoint]) {
                right = midpoint
            } else {
                left = midpoint
            }
            midpoint = (left + right) / 2
        }
        return predicate(a[left]) ? pathAt(left) : predicate(a[right]) ? pathAt(right) : nil
    }
    
    /**
        Find the path of the last item that would appear in the stream before the
        exemplar item.  The exemplar item need not be in this stream.
        
        :param: item    The exemplar item.
    
        :returns:   The index path of that first item or nil if none is found.
    */
    public func findLastIndexPathBefore(item: BaseItem) -> NSIndexPath? {
        let a = array.rawArray
        if a.isEmpty {
            return nil
        }
        let predicate = { self.comparator($0, item) }
        var left = array.startIndex
        var right = array.endIndex - 1
        
        if predicate(a.last!) {
            return pathAt(right)
        }
        
        var midpoint = a.count / 2
        while right - left > 1 {
            if predicate(a[midpoint]) {
                left = midpoint
            } else {
                right = midpoint
            }
            midpoint = (left + right) / 2
        }
        return predicate(a[right]) ? pathAt(right) : (predicate(a[left]) ? pathAt(left) : nil)
    }
    
    /**
        Request to fetch more content at a given offset.
    
        If there is already an ongoing fetch, does not issue another fetch but does invoke done callback.

        :param: count   The number of items to fetch.
        :param: start  The offset (key) at which to start fetching (inclusive).
        :param: end  The offset (key) at which to end fetching (inclusive).
        :param: done    A callback invoked when the fetch is done.
    */
    public func fetchMore(count: Int, start: String, end: String? = nil, done: (Void -> Void)? = nil) {
        if arrayBeforePredicate.count == 0 || isFetchingMore {
            done?()
            return
        }
        isFetchingMore = true
        let fetchMoreQuery = queryPager(start: start, end: end, limit: count + 1)
        fetchMoreQuery.observeSingleEventOfType(.Value, withBlock: { snapshot in
            let inflight = Inflight()
            self.isFetchingMore = false
            self.batching { a in
                if let result = snapshot.value as? [String: [String: AnyObject]] {
                    for (key, dict) in result {
                        if self.arrayBeforePredicate.find(key) == nil {
                            let item = self.type.init(key: key)
                            item.update(dict)
                            self.didConstructItem(item)
                            self.arrayBeforePredicate.append(item)
                            if self.predicate == nil || self.predicate!(item) {
                                a.append(item)
                            }
                        }
                    }
                    inflight.hold()
                }
            }
            done?()
        })
    }
    
    /**
        Called to notify the stream that an item in it has changed which may affect the predicate
        or sort order.  If you have local properties on items that affect streams, consider
        adding a listener in your StreamBase subclass that invokes this method.

        :param: item    The item that changed.  Ignores items that are not part of the stream.
    */
    public func handleItemChanged(item: BaseItem) {
        if item.key == nil || !arrayBeforePredicate.has(item.key!) {
            return
        }
        
        // This change might invalidate an in-flight batch - eg, when changing the predicate.
        finishOutstandingBatch()
        
        var prevPath: NSIndexPath? = nil
        if let row = array.find(item.key!) {
            prevPath = pathAt(row)
        }
        let prev = prevPath != nil
        let cur = predicate == nil || predicate!(item)
        switch (prev, cur) {
        case (true, true):
            delegate?.streamItemsChanged([prevPath!])
        case (true, false):
            batching { a in
                if let newRow = a.find(item.key!) {
                    a.removeAtIndex(newRow)
                }
            }
        case (false, true):
            batching { a in
                if a.find(item.key!) == nil {
                    a.append(item)
                }
            }
        default:
            break
        }
    }
    
    /**
        Subclasses should call this function to make changes to the underlying array of items.
        The callback will be invoked with the current state of the array, which the caller
        can then manipulate.  After some time (@batchDelay), all changes are coallesced and
        delegates are notified.  Note that the order of elements in the array passed to the 
        callback is ignored, so appending is always preferred to insertion.

        :param: fn  The function the client provides to manipulate the array.
    */
    func batching(fn: KeyedArray<BaseItem> -> Void) {
        if !isBatching {
            batchArray.reset(array)
        }
        fn(batchArray)
        scheduleBatch()
    }
    
    private func scheduleBatch() {
        isBatching = true
        if let delay = batchDelay {
            timer?.invalidate()
            timer = NSTimer.schedule(delay: delay) { [weak self] timer in
                self?.finishOutstandingBatch()
            }
        } else {
            finishOutstandingBatch()
        }
    }
    
    private func finishOutstandingBatch() {
        if isBatching {
            timer?.invalidate()
            isBatching = false
            
            let sortedBatch = batchArray.rawArray.sort(comparator)
            StreamBase.applyBatch(array, batch: sortedBatch, delegate: delegate, limit: afterPredicateLimit)
            
            if shouldTellDelegateInitialLoadIsDone == true {
                shouldTellDelegateInitialLoadIsDone = nil
                delegate?.streamDidFinishInitialLoad(nil)
            }
        }
    }
    
    /**
        Given two sorted arrays - the current and next(batch) versions - compute the changes
        and invoke the delegate with any updates.

        :param: current The existing array before applying the batch.  Must be sorted.
        :param: batch   The new array after applying batch.  Must be sorted.
        :param: delegate    The delegate to notify of differences.
        :param: limit   A limit that is applied to the batch.  NOTE: this is after the predicate is evaluated.
    */
    class func applyBatch(current: KeyedArray<BaseItem>, batch: [BaseItem], delegate: StreamBaseDelegate?, limit: Int? = nil) {
        var limitedBatch = batch
        if let l = limit where batch.count > l {
            limitedBatch = Array(limitedBatch[0..<l])
        }
        let (deletes, adds) = diffFrom(current.rawArray, to: limitedBatch)
        current.reset(limitedBatch)
        if let d = delegate {
            if !deletes.isEmpty || !adds.isEmpty {
                d.streamWillChange()
                if !deletes.isEmpty {
                    d.streamItemsDeleted(deletes.map{ NSIndexPath(forRow: $0, inSection: 0) })
                }
                if !adds.isEmpty {
                    d.streamItemsAdded(adds.map{ NSIndexPath(forRow: $0, inSection: 0) })
                }
                d.streamDidChange()
            }
        }
    }
    
    /**
        Given sorted arrays <from> and <to>, produce the deletes (indexed in from)
        and adds (indexed in to) that are required to transform <from> to <to>.
    
        :param: from    The source array for computing differences.  Must be sorted.
        :param: to  The target array for computing differences.  Must be sorted.
    
        :returns: A tuple of two arrays.  The first is the indices of the deletes 
        in the from array.  The second is the indices of the adds in the to array.
    */
    private class func diffFrom(from: [BaseItem], to: [BaseItem]) -> ([Int], [Int]) {
        var deletes = [Int]()
        var adds = [Int]()
        let fromKeys = Set(from.map{ $0.key! })
        let toKeys = Set(to.map{ $0.key! })
        for (i, item) in from.enumerate() {
            if !toKeys.contains(item.key!) {
                deletes.append(i)
            }
        }
        for (i, item) in to.enumerate() {
            if !fromKeys.contains(item.key!) {
                adds.append(i)
            }
        }
        return (deletes, adds)
    }
    
    private final func pathAt(row: Int) -> NSIndexPath {
        return NSIndexPath(forRow: row, inSection: 0)
    }
}

// MARK: SequenceType

extension StreamBase : Indexable {
    public typealias Index = Int
    
    public subscript(i: Index) -> BaseItem {
        return array[i]
    }
    
    public var startIndex: Index {
        return array.startIndex
    }
    
    public var endIndex: Index {
        return array.endIndex
    }
}

extension StreamBase : CollectionType { }