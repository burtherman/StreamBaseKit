//
//  StreamBaseDelegate.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/3/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation

/**
    Delegate invoked with StreamBase changes.  The semantics of this are intended
    to align with UITableView and UICollectionView.  For example, deleted paths are
    expected to be processed first, and so their indices are based on the array before
    any changes have been made.  Additionally, adds and deletes are batched and wrapped
    in will/did change methods.
*/
public protocol StreamBaseDelegate: class {
    /**
        A batch of changes is beginning.
    */
    func streamWillChange()
    
    /**
        A batch of changes has ended.
    */
    func streamDidChange()
    
    /**
        Several items have been added.  These paths indicate where these items will appear
        after the update.
    */
    func streamItemsAdded(paths: [NSIndexPath])
    
    /**
        Several items have been deleted.  These paths indicate where in the original table
        or collection them items were.
    */
    func streamItemsDeleted(paths: [NSIndexPath])
    
    /**
        Several items have changed.
    */
    func streamItemsChanged(paths: [NSIndexPath])
    
    /**
        The initial fetch has completed.  Only called once.
        
        :param: error   Error, if any.
    */
    func streamDidFinishInitialLoad(error: NSError?)
}
