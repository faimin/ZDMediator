//
//  ZDMOneForAll.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/7/2.
//

#import "ZDMOneForAll+Private.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMInvocation.h"
#import "ZDMProxy.h"

static NSString * const zdmJoinKey = @"--->";

NS_INLINE NSString *zdmStoreKey(NSString *serviceName, NSNumber *priority) {
    return [NSString stringWithFormat:@"%@%@%@", serviceName, zdmJoinKey, priority];
}

@implementation ZDMOneForAll

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZDMOneForAll *instance = nil;
    if (instance) {
        return instance;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
        [instance _setup];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self shareInstance];
}

#pragma mark - Inner Method

- (void)_setup {
    _lock = ({
        __auto_type *lock = [[NSRecursiveLock alloc] init];
        lock.name = @"ZDMOneForAll_lock";
        lock;
    });
    _registerInfoMap = @{}.mutableCopy;
    _registerClsMap = @{}.mutableCopy;
    _priorityMap = @{}.mutableCopy;
    _instanceMap = @{}.mutableCopy;
    _serviceResponderMap = @{}.mutableCopy;
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self _loadRegisterFromMacho];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        printf(">>>> times of read one for all macho：%f millisecond\n", (end - start)*1000);
    });
}

+ (void)_loadRegisterFromMacho {
    ZDMOneForAll *mediator = [self shareInstance];
    NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap = mediator.registerInfoMap;
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *clsMap = mediator.registerClsMap;
    NSMutableDictionary<NSString *, NSMutableOrderedSet<NSNumber *> *> *priorityMap = mediator.priorityMap;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceMap = mediator.instanceMap;
    
    __auto_type lock = mediator.lock;
    
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
#ifdef __LP64__
        const struct mach_header_64 *mhp = (void *)_dyld_get_image_header(i);
#else
        const struct mach_header *mhp = (void *)_dyld_get_image_header(i);
#endif
        
        unsigned long size = 0;
        uint8_t *sectionData = getsectiondata(mhp, SEG_DATA, ZDMediatorOFASectionName, &size);
        if (!sectionData) {
            continue;
        }
        
        struct ZDMMachoOFARegisterKV *items = (struct ZDMMachoOFARegisterKV *)sectionData;
        uint64_t itemCount = size / sizeof(struct ZDMMachoOFARegisterKV);
        for (uint64_t i = 0; i < itemCount; ++i) {
            @autoreleasepool {
                struct ZDMMachoOFARegisterKV item = items[i];
                if (!item.key || !item.value) {
                    continue;
                }
                
                Class value = objc_getClass(item.value);
                NSString *serviceName = [NSString stringWithUTF8String:item.key];
                NSString *clsName = [NSString stringWithCString:item.value encoding:NSUTF8StringEncoding];
                __auto_type serviceBox = ({
                    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:value];
                    box.protocolName = serviceName;
                    box.priority = item.priority;
                    box.autoInit = item.autoInit == 1;
                    box.isAllClsMethod = item.allClsMethod == 1;
                    if (box.isAllClsMethod) {
                        ZDMServiceItem *serviceItem = [ZDMServiceItem itemWithStrongObj:value weakObj:nil];
                        if (clsName) {
                            [lock lock];
                            instanceMap[clsName] = serviceItem;
                            [lock unlock];
                        }
                    }
                    box;
                });
                
                NSNumber *priorityNum = @(item.priority);
                
                [lock lock];
                NSMutableOrderedSet *orderSet = priorityMap[serviceName];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    priorityMap[serviceName] = orderSet;
                }
#if DEBUG
                if ([orderSet containsObject:priorityNum]) {
                    Class aClass = storeMap[zdmStoreKey(serviceName, priorityNum)].cls;
                    NSString *aClassName = NSStringFromClass(aClass);
                    NSString *bClassName = [NSString stringWithUTF8String:item.value];
                    NSAssert3(NO, @"⚠️同一Protocol下有多个类注册了相同的Priority => %d, Class => [%@, %@] ", item.priority, aClassName, bClassName);
                }
#endif
                [orderSet addObject:priorityNum];
                
                // store to storeMap
                NSString *protocolPriorityKey = zdmStoreKey(serviceName, priorityNum);
                storeMap[protocolPriorityKey] = serviceBox;
                
                // store to clsMap
                NSMutableSet<NSString *> *protocolPriorityKeySet = clsMap[clsName];
                if (!protocolPriorityKeySet) {
                    protocolPriorityKeySet = [[NSMutableSet alloc] initWithCapacity:2];
                    clsMap[clsName] = protocolPriorityKeySet;
                }
                [protocolPriorityKeySet addObject:protocolPriorityKey];
                
                [lock unlock];
            }
        }
        
        // sort (降序)
        [lock lock];
        [priorityMap enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSMutableOrderedSet<NSNumber *> *_Nonnull obj, BOOL *_Nonnull stop) {
            [obj sortUsingComparator:^NSComparisonResult(NSNumber *_Nonnull obj1, NSNumber *_Nonnull obj2) {
                return [obj2 compare:obj1];
            }];
        }];
        [lock unlock];
    }
}

#pragma mark - Public Method

#pragma mark Set

+ (void)registerService:(Protocol *)serviceProtocol 
               priority:(NSInteger)priority
         implementClass:(Class)cls {
    if (!serviceProtocol) {
        return;
    }
    
    NSString *serviceName = NSStringFromProtocol(serviceProtocol);
    if (!serviceName) {
        return;
    }
    
    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:cls];
    box.priority = priority;
    
    [self _storeServiceWithName:serviceName serviceBox:box];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol 
                  implementer:(id)obj {
    [self manualRegisterService:serviceProtocol priority:ZDMDefaultPriority implementer:obj weakStore:NO];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol
                     priority:(NSInteger)priority
                  implementer:(id)obj
                    weakStore:(BOOL)weakStore {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *serviceName = NSStringFromProtocol(serviceProtocol);
    if (!serviceName) {
        return;
    }
    
    ZDMServiceBox *box = [[ZDMServiceBox alloc] init];
    box.priority = priority;
    box.autoInit = NO;
    // 如果手动注册的是类对象，则认为协议都是类方法
    box.isAllClsMethod = object_isClass(obj);
    box.cls = [obj class];
    
    [self _storeServiceWithName:serviceName serviceBox:box];
    [self _storeServiceWithStrongObj:(weakStore ? nil : obj) weakObj:(weakStore ? obj : nil)];
}

#pragma mark Get

+ (id)service:(Protocol *)serviceProtocol priority:(NSInteger)priority {
    NSString *key = NSStringFromProtocol(serviceProtocol);
    return [self serviceWithName:key priority:priority];
}

+ (id)serviceWithName:(NSString *)serviceName priority:(NSInteger)priority {
    return [self _serviceWithName:serviceName priority:priority needProxyWrap:YES];
}

+ (BOOL)removeService:(Protocol *)serviceProtocol
             priority:(NSInteger)priority
        autoInitAgain:(BOOL)autoInitAgain {
    if (!serviceProtocol) {
#if DEBUG
        NSLog(@"❌ >>>>> the protocol is nil");
#if ENABLE_ASSERT
        NSAssert(NO, @"the protocol is nil");
#endif
#endif
        return NO;
    }
    
    NSString *serviceName = NSStringFromProtocol(serviceProtocol);
    if (!serviceName) {
#if DEBUG
        NSLog(@"❌ >>>>> the protocol name is nil");
#if ENABLE_ASSERT
        NSAssert(NO, @"the protocol name is nil");
#endif
#endif
        return NO;
    }
    
    ZDMOneForAll *mediator = [ZDMOneForAll shareInstance];
    NSString *key = zdmStoreKey(serviceName, @(priority));
    
    [mediator.lock lock];
    [mediator.priorityMap[serviceName] removeObject:@(priority)];
    ZDMServiceBox *serviceBox = mediator.registerInfoMap[key];
    serviceBox.autoInit = autoInitAgain;
    
    NSString *clsName = NSStringFromClass([serviceBox.cls class]);
    ZDMServiceItem *item;
    if (clsName) {
        item = mediator.instanceMap[clsName];
        mediator.instanceMap[clsName] = nil;
    }
    [mediator.lock unlock];
    
    if (item) {
        [item clear];
        item = nil;
        return YES;
    }
    return NO;
}

+ (NSHashTable *)allInitializedObjects {
    [self _loadRegisterIfNeed];
    
    NSHashTable *table = [NSHashTable weakObjectsHashTable];
    [[self shareInstance].instanceMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, ZDMServiceItem * _Nonnull obj, BOOL * _Nonnull stop) {
        id value = obj.obj;
        if (value) {
            [table addObject:value];
        }
    }];
    return table;
}

+ (NSSet<Class> *)allRegisterCls {
    static NSSet<Class> *set = nil;
    if (set) {
        return set;
    }
    
    [self _loadRegisterIfNeed];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet<Class> *clsSet = [[NSMutableSet alloc] init];
        [[self shareInstance].registerInfoMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, ZDMServiceBox * _Nonnull obj, BOOL * _Nonnull stop) {
            [clsSet addObject:obj.cls];
        }];
        set = clsSet.copy;
    });
    return set;
}

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ... {
    if (!serviceProtocol) {
        return;
    }
    
    __auto_type lock = [self shareInstance].lock;
    [lock lock];
    va_list args;
    va_start(args, eventId);
    NSString *value = eventId;
    while (value) {
        [self _registerRespondService:serviceProtocol priority:priority eventKey:value];
        value = va_arg(args, NSString *);
    }
    va_end(args);
    [lock unlock];
}

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ... {
    if (!serviceProtocol) {
        return;
    }
    
    __auto_type lock = [self shareInstance].lock;
    [lock lock];
    va_list args;
    va_start(args, selector);
    SEL value = selector;
    while (value) {
        NSString *key = NSStringFromSelector(value);
        [self _registerRespondService:serviceProtocol priority:priority eventKey:key];
        value = va_arg(args, SEL);
    }
    va_end(args);
    [lock unlock];
}

#pragma mark - Dispatch

+ (NSArray<id> *)dispatchWithProtocol:(Protocol *)protocol
                           selAndArgs:(SEL)selector, ... {
    if (!protocol || !selector) {
        return @[];
    }
    
    [self _loadRegisterIfNeed];
    
    NSString *serviceName = NSStringFromProtocol(protocol);
    ZDMOneForAll *mediator = [self shareInstance];
    [mediator.lock lock];
    NSMutableOrderedSet<NSNumber *> *orderSet = mediator.priorityMap[serviceName];
    [mediator.lock unlock];
    if (!orderSet) {
        return @[];
    }
    
    NSMutableArray *results = @[].mutableCopy;
    for (NSNumber *priorityNum in orderSet.copy) {
        NSString *key = zdmStoreKey(serviceName, priorityNum);
        [mediator.lock lock];
        ZDMServiceBox *box = mediator.registerInfoMap[key];
        [mediator.lock unlock];
        if (!box) {
            continue;
        }
        NSString *clsName = NSStringFromClass(box.cls);
        id serviceInstance = [self _serviceInstaceWithClassName:clsName];
        if (!serviceInstance) {
            if (box.isAllClsMethod) {
                serviceInstance = box.cls;
            } else if ([box.cls respondsToSelector:@selector(zdm_createInstance:)]) {
                serviceInstance = [box.cls zdm_createInstance:mediator.context];
            } else {
                serviceInstance = [[box.cls alloc] init];
            }
            [self _storeServiceWithStrongObj:serviceInstance weakObj:nil];
        };
        
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:serviceInstance invokeSelector:selector args:args];
        if (res) {
            [results addObject:res];
        }
        va_end(args);
    }
    return results.copy;
}

+ (NSArray *)dispatchWithEventId:(NSString *)eventId
                      selAndArgs:(nonnull SEL)selector, ... {
    if (!selector) {
        return @[];
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = [self shareInstance];
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderMap[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        [mediator.lock lock];
        NSOrderedSet *prioritySet = mediator.priorityMap[obj.serviceName];
        [mediator.lock unlock];
        for (NSNumber *priorityNum in prioritySet) {
            @autoreleasepool {
                // ZDMInvocation中做了安全校验，不需要用proxy包装
                id serviceInstance = [self _serviceWithName:obj.serviceName priority:priorityNum.integerValue needProxyWrap:NO];
                if (!serviceInstance) {
                    continue;
                }
                
                va_list args;
                va_start(args, selector);
                id res = [ZDMInvocation target:serviceInstance invokeSelector:selector args:args];
                va_end(args);
                
                if (res) {
                    [results addObject:res];
                }
            }
        }
    }
    return results;
}

+ (NSArray<id> *)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) {
        return @[];
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSString *eventId = NSStringFromSelector(selector);
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderMap[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        [mediator.lock lock];
        NSOrderedSet *prioritySet = mediator.priorityMap[obj.serviceName];
        [mediator.lock unlock];
        for (NSNumber *priorityNum in prioritySet) {
            @autoreleasepool {
                // ZDMInvocation中做了安全校验，不需要用proxy包装
                id module = [self _serviceWithName:obj.serviceName priority:priorityNum.integerValue needProxyWrap:NO];
                if (!module) {
                    continue;
                }
                
                va_list args;
                va_start(args, selector);
                id res = [ZDMInvocation target:module invokeSelector:selector args:args];
                va_end(args);
                
                if (res) {
                    [results addObject:res];
                }
            }
        }
    }
    return results;
}

+ (NSArray<id> *)dispatchWithSELAndArgs:(SEL)selector, ... {
    if (!selector) {
        return @[];
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSMutableArray *results = @[].mutableCopy;
    
    NSArray<NSString *> *allKeys = nil;
    [mediator.lock lock];
    allKeys = mediator.registerInfoMap.allKeys.copy;
    [mediator.lock unlock];
    
    for (NSString *key in allKeys) {
        [mediator.lock lock];
        ZDMServiceBox *serviceBox = mediator.registerInfoMap[key];
        NSString *serviceName = serviceBox.protocolName;
        NSString *clsName = NSStringFromClass(serviceBox.cls) ?: @"";
        NSObject *serviceObj = mediator.instanceMap[clsName].obj;
        [mediator.lock unlock];
        
        if (!serviceObj || ![serviceObj respondsToSelector:selector]) {
            serviceObj = [self _serviceWithName:serviceName priority:serviceBox.priority needProxyWrap:NO];
        }
        if (!serviceObj) {
            continue;
        }
        
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:serviceObj invokeSelector:selector args:args];
        va_end(args);
        
        if (res) {
            [results addObject:res];
        }
    }
    return results;
}

#pragma mark - Private Method

+ (void)_registerRespondService:(Protocol *)serviceName
                       priority:(NSInteger)priority
                       eventKey:(NSString *)eventKey {
    if (!serviceName || !eventKey) {
        return;
    }
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSMutableOrderedSet<ZDMEventResponder *> *orderSet = mediator.serviceResponderMap[eventKey];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        mediator.serviceResponderMap[eventKey] = orderSet;
    }
    
    ZDMEventResponder *respondModel = ({
        ZDMEventResponder *model = [[ZDMEventResponder alloc] init];
        model.serviceName = NSStringFromProtocol(serviceName);
        model.priority = priority;
        model;
    });
    
    if ([orderSet containsObject:respondModel]) {
        [orderSet removeObject:respondModel];
    }
    
    __block NSInteger position = NSNotFound;
    [orderSet enumerateObjectsUsingBlock:^(ZDMEventResponder *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if (obj.priority <= priority) {
            [orderSet insertObject:respondModel atIndex:idx];
            position = idx;
            *stop = YES;
        }
    }];
    if (position == NSNotFound) {
        [orderSet addObject:respondModel];
    }
}

+ (id)_serviceWithName:(NSString *)serviceName priority:(NSInteger)priority needProxyWrap:(BOOL)needWrap {
    if (!serviceName) {
        return nil;
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSString *key = zdmStoreKey(serviceName, @(priority));
    [mediator.lock lock];
    ZDMServiceBox *box = mediator.registerInfoMap[key];
    if (!box && priority == ZDMDefaultPriority) {
        NSNumber *prioNum = mediator.priorityMap[serviceName].firstObject;
        NSString *newKey = zdmStoreKey(serviceName, prioNum);
        box = mediator.registerInfoMap[newKey];
    }
    [mediator.lock unlock];
    if (!box) {
        NSLog(@"❌ >>>>> please register class first");
        return nil;
    }
    
    id serviceInstance = nil;
    NSString *clsName = NSStringFromClass(box.cls);
    if (clsName) {
        serviceInstance = [self _serviceInstaceWithClassName:clsName];
    }
    
    __auto_type createInstanceBlock = ^id(ZDMServiceBox *innerBox, ZDMContext *context){
        Class aCls = innerBox.cls;
        if (!aCls) {
            NSLog(@"❌ >>>>> %d, %s => please register first", __LINE__, __FUNCTION__);
            return nil;
        }
        id instanceOrCls = nil;
        BOOL needInitialize = NO;
        if (innerBox.isAllClsMethod) {
            instanceOrCls = aCls;
        } else if ([aCls respondsToSelector:@selector(zdm_createInstance:)]) {
            instanceOrCls = [aCls zdm_createInstance:context];
        } else {
            // initialize after store to avoid loop call
            instanceOrCls = [aCls alloc];
            needInitialize = YES;
        }
        
        [self _storeServiceWithStrongObj:instanceOrCls weakObj:nil];
        
        if (needInitialize) {
            __unused id _ = [instanceOrCls init];
        }
        return instanceOrCls;
    };
    
    if (!serviceInstance && box.autoInit) {
        serviceInstance = createInstanceBlock(box, mediator.context);
    }
    
    if (!serviceInstance) {
        NSLog(@"❌ >>>>> Finally, the instance object was not found");
    }
    
    // prevent crashes
    if (serviceInstance && needWrap) {
        ZDMProxy *proxyValue = [ZDMProxy proxyWithTarget:serviceInstance];
        __weak typeof(box) weakBox = box;
        __weak typeof(mediator) weakMediator = mediator;
        [proxyValue fixmeWithCallback:^id{
            __strong typeof(weakBox) box = weakBox;
            __strong typeof(weakMediator) mediator = weakMediator;
            // 执行到这个闭包说明协议中不都是类方法，需要修改这个属性
            box.isAllClsMethod = NO;
            
            id value = createInstanceBlock(box, mediator.context);
            return value;
        }];
        return proxyValue;
    }
    return serviceInstance;
}

+ (void)_storeServiceWithName:(NSString *)serviceName serviceBox:(ZDMServiceBox *)box {
    __auto_type mediator = ZDMOneForAll.shareInstance;
    NSNumber *priorityNum = @(box.priority);
    
    [mediator.lock lock];
    NSMutableOrderedSet<NSNumber *> *orderSet = mediator.priorityMap[serviceName];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
    }
#if DEBUG
    if ([orderSet containsObject:priorityNum]) {
        Class aClass = mediator.registerInfoMap[zdmStoreKey(serviceName, priorityNum)].cls;
        NSString *aClassName = NSStringFromClass(aClass);
        NSString *bClassName = NSStringFromClass(box.cls);
        NSAssert3(NO, @"❌ >>>>> 注册了相同priority的service,请修改 => priority: %ld, %@, %@", box.priority, aClassName, bClassName);
    }
#endif
    [orderSet addObject:priorityNum];
    [orderSet sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];
    
    mediator.registerInfoMap[zdmStoreKey(serviceName, priorityNum)] = box;
    [mediator.lock unlock];
}

+ (void)_storeServiceWithStrongObj:(id)strongObj weakObj:(id)weakObj {
    if (!strongObj && !weakObj) {
        return;
    }
    
    NSString *clsName = NSStringFromClass([strongObj ?: weakObj class]);
    
    __auto_type mediator = ZDMOneForAll.shareInstance;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceMap = mediator.instanceMap;
    
    ZDMServiceItem *item = [ZDMServiceItem itemWithStrongObj:strongObj weakObj:weakObj];
    [mediator.lock lock];
    instanceMap[clsName] = item;
    [mediator.lock unlock];
}

+ (id)_serviceInstaceWithClassName:(NSString *)clsName {
    if (!clsName) {
        return nil;
    }
    
    __auto_type mediator = ZDMOneForAll.shareInstance;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceMap = mediator.instanceMap;
    
    [mediator.lock lock];
    ZDMServiceItem *item = instanceMap[clsName];
    [mediator.lock unlock];
    
    return item.obj;
}

#pragma mark - Property

- (ZDMBroadcastProxy *)proxy {
    if (!_proxy) {
        _proxy = [[ZDMBroadcastProxy alloc] initWithTargetSet:[ZDMOneForAll allRegisterCls]];
    }
    return _proxy;
}

@end
