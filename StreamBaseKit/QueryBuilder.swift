//
//  QueryBuilder.swift
//  Pods
//
//  Created by Steve Farrell on 9/2/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.

import Foundation
import Firebase

/**
    Helper for constructing queries.  This is needed because StreamBase does a lot
    of client side processing, and so needs to duplicate some functionality of the 
    Firebase query.  Additionally, it's not possible to inspect FQuery, so instead
    we generate FQuery objects based on specs provided here.
*/
public class QueryBuilder {
    var ref: Firebase
    
    /**
        The maximum number of results to return.  If nil, the whole collection is
        fetched (or at least attempted to be...)
    */
    public var limit: Int?
    
    /**
        Whether to present the collection in ascending (default, Firebase native)
        or descending order.  The latter is needed for messaging apps.
    */
    public var ascending = true
    
    /**
        The sort order.
    */
    public var ordering = StreamBase.Ordering.Key
    
    /**
        Where to start querying.  If ordering is key this is a key, otherwise it
        is a child value.
    */
    public var start: AnyObject?

    /**
        Where to end querying.  If ordering is key this is a key, otherwise it
        is a child value.
    */
    public var end: AnyObject?

    /**
        Construct a builder.

        :param: ref The firebase ref for the collection.
    */
    public init(ref: Firebase) {
        self.ref = ref
    }

    func buildComparator() -> StreamBase.Comparator {
        let comp: StreamBase.Comparator
        switch ordering {
        case .Key:
            comp = { (a, b) in a.key < b.key }
        case .Child(let key):
            // https://www.firebase.com/docs/web/guide/retrieving-data.html#section-ordered-data
            // TODO: Compare unlike types correctly.
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
        return (ascending) ? comp : { comp($1, $0) }
    }
    
    func buildQueryPager() -> StreamBase.QueryPager {
        var query: FQuery
        switch ordering {
        case .Key:
            query = ref.queryOrderedByKey()
        case .Child(let key):
            query = ref.queryOrderedByChild(key)
        }
        return { (start, end, limit) in
            if self.ascending {
                if let s: AnyObject = start {
                    query = query.queryStartingAtValue(s)
                }
                if let e: AnyObject = end {
                    query = query.queryEndingAtValue(e)
                }
                if let l = limit {
                    query = query.queryLimitedToFirst(UInt(l + 1))
                }
                return query
            } else {
                if let s: AnyObject = start {
                    query = query.queryEndingAtValue(s)
                }
                if let e: AnyObject = end {
                    query = query.queryStartingAtValue(e)
                }
                if let l = limit {
                    query = query.queryLimitedToLast(UInt(l + 1))
                }
                return query
            }
        }
    }
    
    func buildQuery() -> FQuery {
        return buildQueryPager()(start: start, end: end, limit: limit)
    }
}
