//
//  StreamTableViewAdapter.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/1/15.
//  Copyright (c) 2015 Steve Farrell. All rights reserved.
//

import Foundation

import UIKit

/**
    An adapter for connecting streams to table views.  Optionally you can set
    the section, which is useful for attaching different streams to different
    sections.  For example,

```
class MyViewController : UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        stream1?.delegate = StreamTableViewAdapter(tableView: tableView, section: 0)
        stream2?.delegate = StreamTableViewAdapter(tableView: tableView, section: 1)
        stream3?.delegate = StreamTableViewAdapter(tableView: tableView, section: 2)
        // ...
    }
}
```
    And then in the data source you do something like this:

```
extension MyViewContoller : UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return stream1?.count ?? 0
        case 1:
            return stream2?.count ?? 0
        case 2:
            return stream3?.count ?? 0
        default:
            fatalError("unknown section \(section)")
        }
    }
    // ... 
}
```
*/
public class StreamTableViewAdapter : StreamBaseDelegate {
    let tableView: UITableView
    let section: Int?
    var isInitialLoad = true
    
    public init(tableView: UITableView, section: Int? = nil) {
        self.tableView = tableView
        self.section = section
        tableView.reloadData()
    }
    
    public func streamWillChange() {
        tableView.beginUpdates()
    }
    
    public func streamDidChange() {
        if isInitialLoad {
            UIView.animateWithDuration(0) {
                self.tableView.endUpdates()
            }
        } else {
            tableView.endUpdates()
        }
    }
    
    public func streamItemsAdded(paths: [NSIndexPath]) {
        if let s = section {
            let mappedPaths = paths.map{ NSIndexPath(forItem: $0.row, inSection: s) }
            tableView.insertRowsAtIndexPaths(mappedPaths, withRowAnimation: .None)
        } else {
            tableView.insertRowsAtIndexPaths(paths, withRowAnimation: .None)
        }
    }
    
    public func streamItemsDeleted(paths: [NSIndexPath]) {
        if let s = section {
            let mappedPaths = paths.map{ NSIndexPath(forItem: $0.row, inSection: s) }
            tableView.deleteRowsAtIndexPaths(mappedPaths, withRowAnimation: .None)
        } else {
            tableView.deleteRowsAtIndexPaths(paths, withRowAnimation: .None)
        }
    }
    
    public func streamItemsChanged(paths: [NSIndexPath]) {
        if let s = section {
            let mappedPaths = paths.map{ NSIndexPath(forItem: $0.row, inSection: s) }
            tableView.reloadRowsAtIndexPaths(mappedPaths, withRowAnimation: .None)
        } else {
            tableView.reloadRowsAtIndexPaths(paths, withRowAnimation: .None)
        }
    }
    
    public func streamDidFinishInitialLoad(error: NSError?) {
        isInitialLoad = false
    }
}
