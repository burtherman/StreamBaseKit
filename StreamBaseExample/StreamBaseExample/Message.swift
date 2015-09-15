//
//  Message.swift
//  StreamBaseExample
//
//  Created by Steve Farrell on 9/14/15.
//  Copyright (c) 2015 Steve Farrell. All rights reserved.
//

import Foundation
import StreamBaseKit

class Message : BaseItem {
    var text: String?
    var username: String?
    
    override func update(dict: [String : AnyObject]?) {
        super.update(dict)
        text = dict?["text"] as? String
        username = dict?["username"] as? String
    }
    
    override var dict: [String: AnyObject] {
        var d = super.dict
        d["text"] = text
        d["username"] = username
        return d
    }
}