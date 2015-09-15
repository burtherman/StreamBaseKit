//
//  Environment.swift
//  StreamBaseExample
//
//  Created by Steve Farrell on 9/14/15.
//  Copyright (c) 2015 Steve Farrell. All rights reserved.
//

import Foundation
import Firebase
import StreamBaseKit

class Environment {
    let resourceBase: ResourceBase
    
    static let sharedEnv: Environment = {
        let firebase = Firebase(url: "https://streambase-example.firebaseio.com")
        let resourceBase = ResourceBase(firebase: firebase)
        let env = Environment(resourceBase: resourceBase)
        let registry: ResourceRegistry = resourceBase
        
        registry.resource(Message.self, path: "/message/@")
        
        return env
    }()
    
    init(resourceBase: ResourceBase) {
        self.resourceBase = resourceBase
    }
}