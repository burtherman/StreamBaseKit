//
//  ResourceBase.swift
//  StreamBaseKit
//
//  Created by Steve Farrell on 9/3/15.
//  Copyright (c) 2015 Movem3nt. All rights reserved.
//

import Foundation
import Firebase

/**
    A dictionary for associating object instances with keys.  These keys are
    used for interpolating paths.
*/
public typealias ResourceDict = [String: BaseItemProtocol]

/**
    An error handler invoked when a persistance operation fails.
*/
public typealias ResourceErrorHandler = (error: NSError) -> Void

/**
    A done handler.  Operation was successful if error is nil.
*/
public typealias ResourceDoneHandler = (error: NSError?) -> Void

/**
    A predicate that is evaluated when updating counters.
*/
public typealias CounterPredicate = BaseItemProtocol -> Bool

/**
    An interface for registering resources, binding classes with the location
    of where they are stored in Firebase.
*/
public protocol ResourceRegistry {
    /// This handler is invoked when persistance operations fail.
    var errorHandler: ResourceErrorHandler? { get set }
    
    /**
        Register a specific type with a path.  Each class can only be registered
        one time.  The path is interpolated dynamically based on context. For 
        example,
    
            registry.resource(Message.self, "group/$group/messages/@")
    
        will have $group interpolated by context, and that the message id
        (represented by "@") will be filled in using childByAutoId() for 
        ```create()``` or the value of the object's key for ```update()``` and 
        ```destroy()```.
    
        If you want to store the same object in two different paths, you can do
        so by subclassing it.
    
        :param: type    The object type being registered.
        :param: path    The path being registered with this object type.
    */
    func resource(type: BaseItemProtocol.Type, path: String)

    /**
        Register a counter so that a field is updated on one object whenever another
        object is created or destroyed.  For example,

            registry.counter(Message.self, "like_count", MessageLike.self)
    
        says that the message's ```like_count``` should be incremented when messages
        are liked, and decremented when those likes are removed.
    
        It's ok to register multiple counters for the same object.
    
        Note that these counters are computed client-side.  You may also need a server-side
        job to correct the inconsistencies that will inevitably occur.
    
        :param: type    The object type that has a counter.
        :param: name    The name of the counter property.
        :param: countingType    The object type that is being counted.
    */
    func counter(type: BaseItemProtocol.Type, name: String, countingType: BaseItemProtocol.Type)
    
    /**
        Register a counter with a predicate.  The predicate can be used to filter which
        objects affect the count.  If the object is updated, the predicate is evaulated
        before and after the change and the counter is updated accordingly.
        
        :param: type    The object type that has a counter.
        :param: name    The name of the counter property.
        :param: countingType    The object type that is being counted.
        :param: predicate   A predicate that determines whether the counter applies.
    */
    func counter(type: BaseItemProtocol.Type, name: String, countingType: BaseItemProtocol.Type, predicate: CounterPredicate?)
}

/**
    Core functionality for persisting BaseItems.  It coordinates the mapping from
    objects to firebase storage through create/update/delete operations.  Extensible
    to provide custom functionality through subclassing.

    NOTE: Client code should not interact with this class directly.  Use the ResourceRegistry
    protocol to register paths, and the far more convient ResourceContext to invoke 
    create/update/destroy.  The public methods in this class generally are so for subclasses.
*/
public class ResourceBase : Printable {
    struct ResourceSpec : Printable {
        let type: BaseItemProtocol.Type
        let path: String

        init(type: BaseItemProtocol.Type, path: String) {
            self.type = type
            self.path = path
        }

        var description: String {
            return "\(path) \(type)"
        }
    }
    
    struct CounterSpec : Printable, Equatable {
        let type: BaseItemProtocol.Type
        let countingType: BaseItemProtocol.Type
        let path: String
        let predicate: CounterPredicate?

        init(type: BaseItemProtocol.Type, countingType: BaseItemProtocol.Type, path: String, predicate: CounterPredicate?) {
            self.type = type
            self.countingType = countingType
            self.path = path
            self.predicate = predicate
        }
        
        var description: String {
            return "\(path) \(type) counting: \(countingType)"
        }
    }
    
    struct ResolvedCounter : Hashable {
        let spec: CounterSpec
        let counterInstance: BaseItemProtocol
        init(spec: CounterSpec, counterInstance: BaseItemProtocol) {
            self.spec = spec
            self.counterInstance = counterInstance
        }

        var hashValue: Int {
            return spec.path.hashValue
        }
    }
    
    let firebase: Firebase
    var resources = [ResourceSpec]()
    var counters = [CounterSpec]()
    
    public var errorHandler: ResourceErrorHandler?
    
    /**
        Construct a new instance.

        :param: firebase    The underlying Firebase store.
    */
    public init(firebase: Firebase) {
        self.firebase = firebase
    }
    
    /// Provide a description including basic stats.
    public var description: String {
        return "ResourceBase with \(resources.count) resources and \(counters.count) counters"
    }

    // MARK: Create hooks
    
    /**
        Called before creating an instance.  Subclass can invoke done handler when ready (eg,
        after performing some network operation, including one with firebase).  If ```done()```
        is not invoked, then nothing happens.  If it's invoked with an error, then the error
        handler is invoked and no futher processing happens.
    
        :param: instance    The instance to create.  Typically the key is nil.
        :param: key The key for the instance.  Typically this is a new auto id.
        :param: context The resouce context for this request.
        :param: done    The handler to call (or not) for storage process to continue.
    */
    public func willCreateInstance(instance: BaseItemProtocol, key: String, context: ResourceContext, done: ResourceDoneHandler) {
        done(error: nil)
    }

    /**
        Called immediately after a newly created instance has added to local storage.  The
        underlying Firebase will asynchronously push that instance to cloud storage.
    
        :param: instance    The instance that was just created with key filled in.
        :param: context The resource context.
    */
    public func didCreateInstance(instance: BaseItemProtocol, context: ResourceContext) {
    }
    
    /**
        Called after a newly created instance has been successfully persisted.  Note that 
        if the client is offline, this may never be called even if the operation succeeeds.  
        For example, the app might be restarted before it goes back online.
    
        :param: instance    The instance just persisted.
        :param: context The resource context.
        :param: error   The error.  If non-nil, the instance is NOT expected to be stored in cloud.
    */
    public func didCreateAndPersistInstance(instance: BaseItemProtocol, context: ResourceContext, error: NSError?) {
    }

    
    // MARK: Update hooks
    
    /**
        Called before updating an instance.  Subclasses can reject this operation by not 
        calling ```done()```.

        :param: instance    The instance being updated.
        :param: context The resource context.
        :param: done    Invoke this when ready to proceed with update.
    */
    public func willUpdateInstance(instance: BaseItemProtocol, context: ResourceContext, done: ResourceDoneHandler) {
        done(error: nil)
    }
    
    /**
        Called immediately after an instance has been updated.

        :param: instance    The instance updated.
        :param: context The resource context.
    */
    public func didUpdateInstance(instance: BaseItemProtocol, context: ResourceContext) {
    }

    /**
        Called after an instance update has been successfully persisted.  Note that if the 
        client is offline, this may never be called even if the operation succeeeds.  For example, 
        the app might be restarted before it goes back online.
        
        :param: instance    The instance just persisted.
        :param: context The resource context.
        :param: error   The error.  If non-nil, the update is NOT expected to be stored in cloud.
    */
    public func didUpdateAndPersistInstance(instance: BaseItemProtocol, context: ResourceContext, error: NSError?) {
    }

    // MARK: Destroy hooks
    
    /**
        Called before deleting an instance.  Subclasses can reject this operation by not 
        calling ```done()```.
        
        :param: instance    The instance being updated.
        :param: context The resource context.
        :param: done    Invoke this when ready to proceed with update.
    */
    
    public func willDestroyInstance(instance: BaseItemProtocol, context: ResourceContext, done: ResourceDoneHandler) {
        done(error: nil)
    }
    
    /**
        Called immediately after an instance has been deleted.
        
        :param: instance    The instance updated.
        :param: context The resource context.
    */
    public func didDestroyInstance(instance: BaseItemProtocol, context: ResourceContext) {
    }

    /**
        Called after an instance delete has been successfully persisted.  Note that if the client
        is offline, this may never be called even if the operation succeeeds.  For example, the
        app might be restarted before it goes back online.
        
        :param: instance    The instance just deleted from persistent store.
        :param: context The resource context.
        :param: error   The error.  If non-nil, the delete is NOT expected to be stored in cloud.
    */
    public func didDestroyAndPersistInstance(instance: BaseItemProtocol, context: ResourceContext, error: NSError?) {
    }
    

    /**
        Return the path part of the Firebase ref.  Eg, if the ref is ```"https://my.firebaseio.com/a/b/c"```,
        this method would return ```"/a/b/c"```.
        
        :param: ref The Firebase ref.
    
        :returns:   The path part of the ref URL.
    */
    public class func refToPath(ref: Firebase) -> String {
        return NSURL(string: ref.description())!.path!
    }
    
    /**
        Override to maintain an log of actions for server-side processing of side-effects, notifications, etc.
        For more information, see: https://medium.com/@spf2/action-logs-for-firebase-30a699200660
        
        :param: path    The path of the resource that just changed.
        :param: old The previous state of the data.  If present, this is an update or delete.
        :param: new The new state of the data.  If present, this is a create or update.
        :param: extraContext    The context values that were not used in resolving the path.
    */
    public func logAction(path: String, old: FDataSnapshot?, new: BaseItemProtocol?, extraContext: ResourceDict) {
    }
    
    class func splitPath(path: String) -> [String] {
        var p = path
        while p.hasPrefix("/") {
            p = dropFirst(p)
        }
        return p.pathComponents
    }
    
    func buildRef(path: String, key: String?, context: ResourceContext) -> Firebase {
        var ref = firebase
        for part in ResourceBase.splitPath(path) {
            if part == "@" {
                if let k = key {
                    ref = ref.childByAppendingPath(k)
                } else {
                    ref = ref.childByAutoId()
                }
            } else if part.hasPrefix("$") {
                let name = dropFirst(part)
                if let obj = context.get(name) {
                    ref = ref.childByAppendingPath(obj.key!)
                } else {
                    fatalError("Cannot find \"\(name)\" for \(path) with context: \(context)")
                }
            } else {
                ref = ref.childByAppendingPath(part)
            }
        }
        return ref
    }
    
    private func log(ref: Firebase, old: FDataSnapshot?, new: BaseItemProtocol?, context: ResourceContext, path: String) {
        var path = ResourceBase.refToPath(ref)
        var extra = ResourceDict()
        let skip = Set(ResourceBase.splitPath(path).filter{ $0.hasPrefix("$") }.map{ dropFirst($0) })
        for (k, v) in context {
            if !skip.contains(k) {
                extra[k] = v
            }
        }
        logAction(path, old: old, new: new, extraContext: extra)
    }
    
    func incrementCounter(ref: Firebase, by: Int) {
        ref.runTransactionBlock({ current in
            var result = max(0, by)
            if let v = current.value as? Int {
                result = v + by
            }
            current.value = result
            return FTransactionResult.successWithValue(current)
        })
    }
    
    func findResourcePath(type: BaseItemProtocol.Type, context: ResourceContext?) -> String? {
        if let path = context?.fullPath {
            return path
        }
        return resources.filter({ $0.type.self === type }).first?.path
    }
    
    func findCounters(countingInstance: BaseItemProtocol, context: ResourceContext) -> [ResolvedCounter] {
        return counters.filter { spec in
            if spec.countingType.self !== countingInstance.dynamicType.self {
                return false
            }
            if let pred = spec.predicate {
                return pred(countingInstance)
            }
            return true
        }.map { spec in
            (spec, self.findCounterInstance(spec.type, context: context))
        }.filter { (spec, instance) in
            instance != nil
        }.map { (spec, instance) in
            ResolvedCounter(spec: spec, counterInstance: instance!)
        }
    }
    
    func findCounterInstance(type: BaseItemProtocol.Type, context: ResourceContext) -> BaseItemProtocol? {
        for (k, v) in context {
            if v.dynamicType.self === type.self {
                return v
            }
        }
        return nil
    }

    /**
        Get the Firebase ref for a given instance in this context.

        :param: instance    The instance.
        :param: context The resource context.

        :returns:   A firebase ref for this instance in this context.
    */
    public func ref(instance: BaseItemProtocol, context: ResourceContext) -> Firebase {
        let path = findResourcePath(instance.dynamicType, context: context)
        assert(path != nil, "Cannot find ref for type \(instance.dynamicType)")
        return buildRef(path!, key: instance.key, context: context)
    }
    
    /**
        Get a Firebase ref for where instances of this type are stored.

        :param: type    The type.
        :param: context The resource context.

        :returns:   A firebase ref where to find instances of the given type.
    */
    public func collectionRef(type: BaseItemProtocol.Type, context: ResourceContext) -> Firebase {
        let path = findResourcePath(type, context: context)
        assert(path != nil, "Cannot find stream for type \(type)")
        return buildRef(path!, key: "~", context: context).parent
    }
    
    /**
        Store a a new item.  If the key is not provided and the path its type is
        registered with contains "@", then an auto-id will be generated.

        :param: instance    The instance to create.
        :param: context The resource context.
    */
    public func create(instance: BaseItemProtocol, context: ResourceContext) {
        let path = findResourcePath(instance.dynamicType, context: context)!
        let ref = buildRef(path, key: instance.key, context: context)
        var inflight: Inflight? = Inflight()
        willCreateInstance(instance, key: ref.key, context: context) { (error) in
            if let err = error {
                self.errorHandler?(error: err)
            } else {
                instance.key = ref.key
                ref.setValue(instance.dict) { (error, ref) in
                    inflight = nil
                    if let err = error {
                        self.errorHandler?(error: err)
                    }
                    self.didCreateAndPersistInstance(instance, context: context, error: error)
                }
                for counter in self.findCounters(instance, context: context) {
                    let counterRef = self.buildRef(counter.spec.path, key: counter.counterInstance.key, context: context)
                    self.incrementCounter(counterRef, by: 1)
                }
                self.log(ref, old: nil, new: instance, context: context, path: path)
                self.didCreateInstance(instance, context: context)
            }
        }
    }
    
    /**
        Store updates made to an item.

        :param: instance    The instance to update.
        :param: context The resource context.
    */
    public func update(instance: BaseItemProtocol, context: ResourceContext) {
        let path = findResourcePath(instance.dynamicType, context: context)!
        let ref = buildRef(path, key: instance.key, context: context)
        var inflight: Inflight? = Inflight()
        willUpdateInstance(instance, context: context) { (error) in
            if let err = error {
                self.errorHandler?(error: err)
            } else {
                ref.observeSingleEventOfType(.Value, withBlock: { snapshot in
                    ref.updateChildValues(instance.dict) { (error, ref) in
                        inflight = nil
                        if let err = error {
                            self.errorHandler?(error: err)
                        }
                        self.didUpdateAndPersistInstance(instance, context: context, error: error)
                    }
                    // If this change affects any counters, do corresponding increments and decrements.
                    if let dict = snapshot.value as? [String: AnyObject] {
                        let prev = instance.clone()
                        prev.update(dict)
                        
                        let prevCounters = Set(self.findCounters(prev, context: context))
                        let curCounters = Set(self.findCounters(instance, context: context))
                        for counter in curCounters.subtract(prevCounters) {
                            let counterRef = self.buildRef(counter.spec.path, key: counter.counterInstance.key, context: context)
                            self.incrementCounter(counterRef, by: 1)
                        }
                        for counter in prevCounters.subtract(curCounters) {
                            let counterRef = self.buildRef(counter.spec.path, key: counter.counterInstance.key, context: context)
                            self.incrementCounter(counterRef, by: -1)
                        }
                    }
                    self.log(ref, old: snapshot, new: instance, context: context, path: path)
                    }, withCancelBlock: { error in
                        self.errorHandler?(error: error)
                })
                self.didUpdateInstance(instance, context: context)
            }
        }
    }
    
    /**
        Remove an item from cloud store.
        
        :param: instance    The instance to update.
        :param: context The resource context.
    */
    public func destroy(instance: BaseItemProtocol, context: ResourceContext) {
        let path = findResourcePath(instance.dynamicType, context: context)!
        let ref = buildRef(path, key: instance.key, context: context)
        var inflight: Inflight? = Inflight()
        willDestroyInstance(instance, context: context) { (error) in
            if let err = error {
                self.errorHandler?(error: err)
            } else {
                ref.observeSingleEventOfType(.Value, withBlock: { snapshot in
                    ref.removeValueWithCompletionBlock { (error, ref) in
                        inflight = nil
                        if let err = error {
                            self.errorHandler?(error: err)
                        }
                        self.didDestroyAndPersistInstance(instance, context: context, error: error)
                    }
                    for counter in self.findCounters(instance, context: context) {
                        let counterRef = self.buildRef(counter.spec.path, key: counter.counterInstance.key, context: context)
                        self.incrementCounter(counterRef, by: -1)
                    }
                    self.log(ref, old: snapshot, new: nil, context: context, path: path)
                    }, withCancelBlock: { error in
                        self.errorHandler?(error: error)
                })
                self.didDestroyInstance(instance, context: context)
            }
        }
    }
}

extension ResourceBase : ResourceRegistry {
    public func resource(type: BaseItemProtocol.Type, path: String) {
        precondition(findResourcePath(type, context: nil) == nil, "Attempted to add resource twice for same type: \(type) at \(path)")
        let spec = ResourceSpec(type: type, path: path)
        resources.append(spec)
    }
    
    public func counter(type: BaseItemProtocol.Type, name: String, countingType: BaseItemProtocol.Type) {
        counter(type, name: name, countingType: countingType, predicate: nil)
    }
    
    public func counter(type: BaseItemProtocol.Type, name: String, countingType: BaseItemProtocol.Type, predicate: CounterPredicate?) {
        let path = "/".join([findResourcePath(type, context: nil)!, name])
        counters.append(CounterSpec(type: type, countingType: countingType, path: path, predicate: predicate))
    }
}

func ==(lhs: ResourceBase.CounterSpec, rhs: ResourceBase.CounterSpec) -> Bool {
    return lhs.path == rhs.path && lhs.countingType === rhs.countingType
    
}

func ==(lhs: ResourceBase.ResolvedCounter, rhs: ResourceBase.ResolvedCounter) -> Bool {
    return lhs.spec == rhs.spec && lhs.counterInstance === rhs.counterInstance
}
