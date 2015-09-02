//
//  StreamBase.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 8/31/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Firebase

public protocol StreamBaseDelegate: class {
    func streamWillChange()
    func streamDidChange()
    func streamItemsAdded(paths: [NSIndexPath])
    func streamItemsDeleted(paths: [NSIndexPath])
    func streamItemsChanged(paths: [NSIndexPath])
    func streamDidFinishInitialLoad()
}

public protocol StreamBaseProtocol: class {
    var delegate: StreamBaseDelegate? { get set }

    func find(key: String) -> StreamBaseItem?
    func findIndexPath(key: String) -> NSIndexPath?
}

public enum BaseOrdering {
    case Key
    case Child(String)
    // TODO Priority
}

public class StreamBase : StreamBaseProtocol {
    public typealias Predicate = StreamBaseItem -> Bool
    public typealias Comparator = (StreamBaseItem, StreamBaseItem) -> Bool
    
    private var handles = [UInt]()
    private var arrayBeforePredicate = KeyedArray<StreamBaseItem>()
    private var array = KeyedArray<StreamBaseItem>()
    private var batchArray = KeyedArray<StreamBaseItem>()
    
    private let type: StreamBaseItem.Type!
    private let ref: Firebase!
    private var query: FQuery!
    private var observer: NSObjectProtocol?
    
    private var isBatching = false
    private var timer: NSTimer?
    private let limit: Int?
    private var isFetchingMore = false
    private var shouldTellDelegateInitialLoadIsDone: Bool? = false
    
    public let comparator: Comparator
    public var batchDelay: NSTimeInterval? = 0.1
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
    public var afterPredicateLimit: Int?
    public weak var delegate: StreamBaseDelegate? {
        didSet {
            if limit == 0 {
                delegate?.streamDidFinishInitialLoad()
            }
        }
    }

    init() {
        type = nil
        limit = 0
        ref = nil
        query = nil
        comparator = { $0.key < $1.key }
    }
    
    //  TODO: Construct with a query instead of ref?
    public init(type: StreamBaseItem.Type, ref: Firebase, limit: Int? = nil, ascending: Bool = true, ordering: BaseOrdering = .Key) {
        self.type = type
        self.ref = ref
        self.limit = limit
        (comparator, query) = StreamBase.configureQuery(ref, ascending: ascending, limit: limit, ordering: ordering)
        
        // NOTE we have to construct a stub instance b/c Swift1.2 doesn't yet support accessing static values in
        // protocols.
        if let name = type(ref: nil, dict: nil).notificationName {
            observer = NSNotificationCenter.defaultCenter().addObserverForName(name, object: nil, queue: nil) { [weak self] notification in
                if let s = self, t = notification.object as? StreamBaseItem where s.arrayBeforePredicate.has(t.key!) {
                    s.handleItemChanged(t)
                }
            }
        }
        
        handles.append(query.observeEventType(.ChildAdded, withBlock: { [weak self] snapshot in
            if let s = self {
                var t = s.type(ref: snapshot.ref, dict: snapshot.value as? [String: AnyObject])
                s.arrayBeforePredicate.append(t)
                if s.predicate == nil || s.predicate!(t) {
                    s.batching { $0.append(t) }
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
                    t.update(snapshot.value as! [String: AnyObject])
                    s.handleItemChanged(t)
                }
            }
            }))
        
        var inflight: Inflight? = Inflight()
        query.observeSingleEventOfType(.Value, withBlock: { [weak self] snapshot in
            inflight = nil
            self?.shouldTellDelegateInitialLoadIsDone = true
            self?.scheduleBatch()
            }, withCancelBlock: { error in
                println(error)
            })
    }
    
    deinit {
        if let obs = self.observer {
            NSNotificationCenter.defaultCenter().removeObserver(obs)
        }
        for h in handles {
            query.removeObserverWithHandle(h)
        }
    }
    
    public func find(key: String) -> StreamBaseItem? {
        if let row = array.find(key) {
            return array[row]
        }
        return nil
    }
    
    public func findIndexPath(key: String) -> NSIndexPath? {
        if let row = array.find(key) {
            return pathAt(row)
        }
        return nil
    }
    
    func findFirstIndexPathWhere(ordering: StreamBaseItem -> Bool) -> NSIndexPath? {
        if let i = array.findFirstWhere(ordering) {
            return pathAt(i)
        }
        return nil
    }
    
    func findLastIndexPathWhere(ordering: StreamBaseItem -> Bool) -> NSIndexPath? {
        if let i = array.findLastWhere(ordering) {
            return pathAt(i)
        }
        return nil
    }
    
    public func fetchMore(count: Int, offset: String, done: (Void -> Void)? = nil) {
        if arrayBeforePredicate.count == 0 || isFetchingMore {
            return
        }
        isFetchingMore = true
        // TODO fix for non-key orderings and check ascending
        let query = ref.queryOrderedByKey().queryEndingAtValue(offset).queryLimitedToLast(UInt(count + 1))
        let inflight = Inflight()
        query.observeSingleEventOfType(.Value, withBlock: { snapshot in
            let i = inflight
            self.isFetchingMore = false
            self.batching { a in
                if let result = snapshot.value as? [String: [String: AnyObject]] {
                    for (key, dict) in result {
                        if self.arrayBeforePredicate.find(key) == nil {
                            var t = self.type(ref: self.ref.childByAppendingPath(key), dict: dict)
                            self.arrayBeforePredicate.append(t)
                            if self.predicate == nil || self.predicate!(t) {
                                a.append(t)
                            }
                        }
                    }
                }
            }
            done?()
        })
    }
    
    // Set up both server-side and client side orderings.
    private static func configureQuery(ref: Firebase, ascending: Bool, limit: Int?, ordering: BaseOrdering) -> (Comparator, FQuery!) {
        let comp: Comparator
        var query: FQuery
        switch ordering {
        case .Key:
            query = ref.queryOrderedByKey()
            comp = { (a, b) in a.key < b.key }
        case .Child(let key):
            query = ref.queryOrderedByChild(key)
            // https://www.firebase.com/docs/web/guide/retrieving-data.html#section-ordered-data
            // TODO: Compare unlike types.
            comp = { (a, b) in
                let av: AnyObject? = a.dict[key] ?? NSNull()
                let bv: AnyObject? = b.dict[key] ?? NSNull()
                switch (av, bv) {
                case (let _ as NSNull, let _ as NSNull):
                    break
                case (let _ as NSNull, _):
                    return true
                case (_, let _ as NSNull):
                    return false
                case (let astr as String, let bstr as String):
                    if astr != bstr {
                        return astr < bstr
                    }
                case (let aflt as Float, let bflt as Float):  // NOTE: Includes Int
                    if aflt != bflt {
                        return aflt < bflt
                    }
                case (let abool as Bool, let bbool as Bool):
                    if abool != bbool {
                        return !abool
                    }
                default:
                    break
                }
                return a.key < b.key
            }
        }
        if let l = limit {
            query = (ascending) ? query.queryLimitedToFirst(UInt(l)) : query.queryLimitedToLast(UInt(l))
        }
        return ((ascending) ? comp : { comp($1, $0) }, query)
    }
    
    private func handleItemChanged(t: StreamBaseItem) {
        // This change might invalidate an in-flight batch - eg, when changing the predicate.
        finishOutstandingBatch()
        
        var prevPath: NSIndexPath? = nil
        if let row = array.find(t.key!) {
            prevPath = pathAt(row)
        }
        let prev = prevPath != nil
        let cur = predicate == nil || predicate!(t)
        switch (prev, cur) {
        case (true, true):
            delegate?.streamItemsChanged([prevPath!])
        case (true, false):
            batching { a in
                if let newRow = a.find(t.key!) {
                    a.removeAtIndex(newRow)
                }
            }
        case (false, true):
            batching { a in
                if a.find(t.key!) == nil {
                    a.append(t)
                }
            }
        default:
            break
        }
    }
    
    func batching(fn: KeyedArray<StreamBaseItem> -> Void) {
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
            
            // TODO: Is it possible to remove this sort()?
            sort(&batchArray.rawArray, comparator)
            StreamBase.applyBatch(array, batch: batchArray.rawArray, delegate: delegate, limit: afterPredicateLimit)
            if shouldTellDelegateInitialLoadIsDone == true {
                shouldTellDelegateInitialLoadIsDone = nil
                delegate?.streamDidFinishInitialLoad()
            }
        }
    }
    
    // NOTE: Expects both arrays to be sorted.
    class func applyBatch(current: KeyedArray<StreamBaseItem>, batch: [StreamBaseItem], delegate: StreamBaseDelegate?, limit: Int? = nil) {
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
    
    // Given *sorted* arrays from and to, produce the deletes (indexed in from)
    // and adds (indexed in to) that are required to transform <from> to <to>.
    private class func diffFrom(from: [StreamBaseItem], to: [StreamBaseItem]) -> ([Int], [Int]) {
        var deletes = [Int]()
        var adds = [Int]()
        var fromKeys = Set<String>(from.map{$0.key!})
        let toKeys = Set<String>(to.map{$0.key!})
        for (i, item) in enumerate(from) {
            if !toKeys.contains(item.key!) {
                deletes.append(i)
            }
        }
        for (i, item) in enumerate(to) {
            if !fromKeys.contains(item.key!) {
                adds.append(i)
            }
        }
        return (deletes, adds)
    }
    
    private func pathAt(row: Int) -> NSIndexPath {
        return NSIndexPath(forRow: row, inSection: 0)
    }
}

extension StreamBase : SequenceType {
    public var count: Int {
        return array.count
    }
    
    public subscript(i: Int) -> StreamBaseItem {
        return array[i]
    }
    
    public func generate() -> GeneratorOf<StreamBaseItem> {
        return array.generate()
    }
}