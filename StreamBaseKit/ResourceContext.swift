//
//  ResourceContext.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/14/15.
//  Copyright (c) 2015 Movem3nt, Inc. All rights reserved.
//

import Foundation
import Firebase

/**
    When used correctly, ResourceContext makes object persistance as simple as this:

        let message = Message()
        message.text = inputField.text
        resourceContext.create(message)

    The ResourceBase keeps track of the mapping between object type and storage.  But,
    to do so, it requires a way to fill in path components.  For example if you've registered:

        registry.register(MessageLike.class, "group/$group/message_like/$message/$user")

    it must resolve ```$group```, ```$message```, and ```$user``` in order to persist this like.
    This is what ResourceContexts are for.

    ResourceContext behaves like a stack, much like the navigation stack in most applications.
    As you push navigation controllers onto the stack, you will also push ResourceContexts.
    Each view controller that interacts with Firebase should have its own ResourceContext.

    It's also common to create transient ResourceContexts inside a function.  For example,

        func handleLike(sender: MessageLikeControl) {
            resourceContext.push(["message": sender.message]).create(MessageLike())
        }

    The ```$user``` should probably be provided at the bottom of the ResourceContext stack.
    One way to do this is to put a "me" and root ResourceContext in a singleton.  The
    initial view controller would then get its ResourceContext by pushing onto this root.

    If the same key appears at different levels of the stack, the value for the higher level
    key will be used.
*/
public class ResourceContext : DebugPrintable {
    let parent: ResourceContext?
    let base: ResourceBase
    var resources: ResourceDict
    
    /**
        Construct a root ResourceContext.  This is typically done once, in a singleton.

        :param: base    The resource base for persistence.
        :param: resources   Resources to associate with the root such as the user "me".
    */
    public init(base: ResourceBase, resources: ResourceDict?) {
        self.parent = nil
        self.base = base
        self.resources = resources ?? [:]
    }
        
    /**
        Construct a new ResourceContext above this parent on the stack.  Clients should
        typically use the more convienent ```push()``` method instead.

        :param: parent  The parent on which to push.
        :param: resources   Resources at this level of the stack.
    */
    public init(parent: ResourceContext, resources: ResourceDict?) {
        self.parent = parent
        self.base = parent.base
        self.resources = resources ?? [:]
    }
    
    /**
        Iterate through the stack from this the top (this ResourceContext).
    */
    public var stack: GeneratorOf<ResourceContext> {
        var current: ResourceContext? = self
        return GeneratorOf<ResourceContext> {
            var ret = current
            current = current?.parent
            return ret
        }
    }
    
    /**
        Provide a description of the stack useful for debugging.
    */
    public var debugDescription: String {
        var parts = [String]()
        for (i, c) in enumerate(reverse(Array<ResourceContext>(stack))) {
            var part = i.description
            for j in 0...i {
                part += "  "
            }
            part += c.resources.description
            parts.append(part)
        }
        
        return "\n".join(parts)
    }
    
    /**
        Resolve a key by checking each level of the stack, starting
        at the top (this ResourceContext).
    
        :param: name    The name of the key to get.  Without "$".
    */
    public func get(name: String) -> BaseItemProtocol? {
        for c in stack {
            if let item = c.resources[name] {
                return item
            }
        }
        return nil
    }
    
    /**
        Reset the resources for this level of the stack.
    
        :param: resources   The new resources.
    */
    public func reset(_ resources: ResourceDict? = nil) {
        self.resources = resources ?? [:]
    }
    
    /**
        Push a new ResourceContext onto the stack and initialize it with the
        specified resources.
    
        :param: resources   The new resources.
    
        :returns:   The new top of the stack.
    */
    public func push(_ resources: ResourceDict? = nil) -> ResourceContext {
        return ResourceContext(parent: self, resources: resources)
    }
    
    /**
        Map from a instance to a Firebase ref.

        :param: instance    The instance.
    
        :returns:   The Firebase ref.
    */
    public func ref(instance: BaseItemProtocol) -> Firebase {
        return base.ref(instance, context: self)
    }
    
    /**
        Map from a type to the Firebase ref where instances of that type are stored.

        :param: type    The type to find a ref for.

        :returns:   The Firebase ref.
    */
    public func collectionRef(type: BaseItemProtocol.Type) -> Firebase {
        return base.collectionRef(type, context: self)
    }
    
    /**
        Persist a new instance.  If the key is nil and there is an "@" in the
        registered path then the key will be filled in with an auto id.
    
        :param: instance    The instance to create.
    */
    public func create(instance: BaseItemProtocol) {
        base.create(instance, context: self)
    }
    
    /**
        Update an existing instance.
    
        :param: instance    The instance to update.
    */
    public func update(instance: BaseItemProtocol) {
        base.update(instance, context: self)
    }
    
    /**
        Destroy an existing instance.
    
        :param: instance    The instance to destroy.
    */
    public func destroy(instance: BaseItemProtocol) {
        base.destroy(instance, context: self)
    }
    
    /**
        Convenience method.  Calls create or update depending on the ```exists``` param.

        :param: instance    The instance to create or update.
        :param: exists  If true call update, otherwise create.
    */
    public func createOrUpdate(instance: BaseItemProtocol, exists: Bool) {
        if exists {
            base.update(instance, context: self)
        } else {
            base.create(instance, context: self)
        }
    }
    
    /**
        Convenience method.  Calls create or destroy depending on the ```exists``` param.
        
        :param: instance    The instance to create or destroy.
        :param: exists  If true call destroy, otherwise create.
    */
    public func toggle(instance: BaseItemProtocol, exists: Bool) {
        if exists {
            base.destroy(instance, context: self)
        } else {
            base.create(instance, context: self)
        }
    }
}

extension ResourceContext : SequenceType {
    public func generate() -> GeneratorOf<(String, BaseItemProtocol)> {
        var stack = self.stack
        var current = stack.next()
        var index = 0
        var seen = Set<String>()
        return GeneratorOf<(String, BaseItemProtocol)> {
            while current != nil {
                for ; index < current!.resources.keys.array.count; index++ {
                    var name = current!.resources.keys.array[index]
                    if !seen.contains(name) {
                        seen.insert(name)
                        return (name, current!.resources[name]!)
                    }
                }
                index = 0
                current = stack.next()
            }
            return nil
        }
    }
}