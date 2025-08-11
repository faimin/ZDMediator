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
#import "NSObject+ZDMOnDealloc.h"

static NSString * const zdmJoinKey = @"--->";

NS_INLINE NSString *zdmStoreKey(NSString *serviceName, NSNumber *priority) {
    NSCAssert(priority, @"priority is nil");
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
    _lock = [[ZDMLock alloc] init];
    _registerInfoDict = @{}.mutableCopy;
    _registerClassDict = @{}.mutableCopy;
    _priorityDict = @{}.mutableCopy;
    _instanceDict = @{}.mutableCopy;
    _serviceResponderDict = @{}.mutableCopy;
    _proxy = [ZDMBroadcastProxy alloc];
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self _loadRegisterFromMacho];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        printf(">>>> times of read one for all macho：%f milliseconds\n", (end - start)*1000);
    });
}

+ (void)_loadRegisterFromMacho {
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap = mediator.registerInfoDict;
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *clsMap = mediator.registerClassDict;
    NSMutableDictionary<NSString *, NSMutableOrderedSet<NSNumber *> *> *priorityDict = mediator.priorityDict;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceDict = mediator.instanceDict;
    
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
                    // 如果类实现了优先级协议,则优先使用协议中的优先级
                    NSInteger effectivePriority = item.priority;
                    if ([value respondsToSelector:@selector(zdm_priority)]) {
                        NSInteger clsPriority = [value zdm_priority];
                        NSCAssert(clsPriority >= NSIntegerMin && clsPriority <= NSIntegerMax, @"priority out of int bounds");
                        effectivePriority = clsPriority;
                    }
                    box.priority = effectivePriority;
                    box.autoInit = item.autoInit == 1;
                    box.isAllClsMethod = item.allClsMethod == 1;
                    if (box.isAllClsMethod) {
                        ZDMServiceItem *serviceItem = [ZDMServiceItem itemWithStrongObj:value weakObj:nil];
                        if (clsName) {
                            [lock lock];
                            instanceDict[clsName] = serviceItem;
                            [lock unlock];
                        }
                    }
                    box;
                });
                
                NSNumber *priorityNum = @(serviceBox.priority);
                NSString *protocolPriorityKey = zdmStoreKey(serviceName, priorityNum);
                
                [lock lock];
                NSMutableOrderedSet<NSNumber *> *orderSet = priorityDict[serviceName];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    priorityDict[serviceName] = orderSet;
                }
#if DEBUG
                if ([orderSet containsObject:priorityNum]) {
                    Class aClass = storeMap[zdmStoreKey(serviceName, priorityNum)].cls;
                    NSString *aClassName = NSStringFromClass(aClass);
                    NSString *bClassName = [NSString stringWithUTF8String:item.value];
                    if (![aClassName isEqualToString:bClassName]) {
                        NSAssert3(NO, @"❌ >>>>> 同一Protocol下有多个类注册了相同的Priority => %d, Class => [%@, %@] ", item.priority, aClassName, bClassName);
                    }
                }
#endif
                [orderSet addObject:priorityNum];
                
                // storeMap中有可能已经存在serviceBox了,
                // 不过不管它,用自动注册的这个serviceBox,
                // 因为自动注册的这个信息更全
                storeMap[protocolPriorityKey] = serviceBox;
                
                // store key to clsMap
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
        [priorityDict enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSMutableOrderedSet<NSNumber *> *_Nonnull obj, BOOL *_Nonnull stop) {
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
    
    Class cls = [obj class];
    NSString *clsName = NSStringFromClass(cls);
    if (!clsName) {
        return;
    }
    
    // 检查是否已经存在自动注册的信息, 有的话就不创建
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSMutableSet<NSString *> *keySet = mediator.registerClassDict[clsName];
    [mediator.lock unlock];
    NSString *key = zdmStoreKey(serviceName, @(priority));
    if (![keySet containsObject:key]) {
#if DEBUG
        NSMutableSet *serviceNameSet = [[NSMutableSet alloc] init];
        for (NSString *key in keySet) {
            NSString *tempServiceName = [key componentsSeparatedByString:zdmJoinKey].firstObject;
            if (!tempServiceName) {
                continue;
            }
            [serviceNameSet addObject:tempServiceName];
        }
        if ([serviceNameSet containsObject:serviceName]) {
            NSAssert2(NO, @"❌ >>>>> you had registered the service: (%@), class: (%@) with another priority", serviceName, clsName);
        } else {
#endif
            ZDMServiceBox *box = [[ZDMServiceBox alloc] init];
            box.priority = priority;
            box.autoInit = NO;
            // 如果手动注册的是类对象，则认为协议都是类方法
            box.isAllClsMethod = object_isClass(obj);
            box.cls = [obj class];
            
            [self _storeServiceWithName:serviceName serviceBox:box];
#if DEBUG
        }
#endif
    }
    [self _storeServiceWithStrongObj:(weakStore ? nil : obj) weakObj:(weakStore ? obj : nil)];
    
    if (weakStore && !object_isClass(obj)) {
        // auto cleanup after obj dealloc
        [((NSObject *)obj) zdm_onDealloc:^(id  _Nullable realTarget) {
            [self removeService:serviceProtocol priority:priority autoInitAgain:NO];
        }];
    }
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
    
    NSString *key = zdmStoreKey(serviceName, @(priority));
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSMutableOrderedSet<NSNumber *> *priorityOrderSet = mediator.priorityDict[serviceName];
    [priorityOrderSet removeObject:@(priority)];
    if (priorityOrderSet.count == 0) {
        mediator.priorityDict[serviceName] = nil;
    }
    
    ZDMServiceBox *serviceBox = mediator.registerInfoDict[key];
    serviceBox.autoInit = autoInitAgain;
    
    NSString *clsName = NSStringFromClass(serviceBox.cls);
    ZDMServiceItem *item = nil;
    BOOL _updateProxy = NO;
    if (clsName) {
        item = mediator.instanceDict[clsName];
        mediator.instanceDict[clsName] = nil;
        
        NSMutableSet<NSString *> *protocolPrioprityKeys = mediator.registerClassDict[clsName];
        [protocolPrioprityKeys removeObject:key];
        // cleanup register info if it didn't auto init agin
        if (!autoInitAgain) {
            if (protocolPrioprityKeys.count == 0) {
                mediator.registerClassDict[clsName] = nil;
            }
            mediator.registerInfoDict[key] = nil;
            
            _updateProxy = YES;
        }
    }
    [mediator.lock unlock];
    
    // update proxy targets
    if (_updateProxy) {
        [self _updateProxyTargets];
    }
    
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
    [ZDMOneForAll.shareInstance.instanceDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, ZDMServiceItem * _Nonnull obj, BOOL * _Nonnull stop) {
        id value = obj.obj;
        if (value) {
            [table addObject:value];
        }
    }];
    return table;
}

+ (NSOrderedSet<Class> *)allRegisterClasses {
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSArray<ZDMServiceBox *> *serviceBoxs = mediator.registerInfoDict.allValues.copy;
    [mediator.lock unlock];
    NSArray<ZDMServiceBox *> *sortedBoxs = [serviceBoxs sortedArrayUsingComparator:^NSComparisonResult(ZDMServiceBox * _Nonnull obj1, ZDMServiceBox * _Nonnull obj2) {
        NSInteger priority1 = obj1.priority;
        NSInteger priority2 = obj2.priority;
#if false
        if ([obj1.cls respondsToSelector:@selector(zdm_priority)]) {
            priority1 = [obj1.cls zdm_priority];
        }
        if ([obj2.cls respondsToSelector:@selector(zdm_priority)]) {
            priority2 = [obj2.cls zdm_priority];
        }
#endif
        NSComparisonResult result = priority1 >= priority2 ? NSOrderedAscending : NSOrderedDescending;
        return result;
    }];
    
    NSMutableOrderedSet<Class> *clsOrderSet = [[NSMutableOrderedSet alloc] init];
    for (ZDMServiceBox *box in sortedBoxs) {
        [clsOrderSet addObject:box.cls];
    }
    return clsOrderSet.copy;
}

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ... {
    if (!serviceProtocol) {
        return;
    }
    
    __auto_type lock = ZDMOneForAll.shareInstance.lock;
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
    
    __auto_type lock = ZDMOneForAll.shareInstance.lock;
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
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSMutableOrderedSet<NSNumber *> *orderSet = mediator.priorityDict[serviceName];
    [mediator.lock unlock];
    if (!orderSet) {
        return @[];
    }
    
    NSMutableArray *results = @[].mutableCopy;
    for (NSNumber *priorityNum in orderSet.copy) {
        NSString *key = zdmStoreKey(serviceName, priorityNum);
        [mediator.lock lock];
        ZDMServiceBox *box = mediator.registerInfoDict[key];
        [mediator.lock unlock];
        if (!box) {
            continue;
        }
        NSString *clsName = NSStringFromClass(box.cls);
        id serviceInstance = [self _serviceInstaceWithClassName:clsName];
        if (!serviceInstance) {
            serviceInstance = [self _createInstance:box];
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
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderDict[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        [mediator.lock lock];
        NSOrderedSet<NSNumber *> *prioritySet = mediator.priorityDict[obj.serviceName].copy;
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
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    NSString *eventId = NSStringFromSelector(selector);
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderDict[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        [mediator.lock lock];
        NSOrderedSet<NSNumber *> *prioritySet = mediator.priorityDict[obj.serviceName].copy;
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
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    NSMutableArray *results = @[].mutableCopy;
    
    NSArray<NSString *> *registerClsNames = nil;
    [mediator.lock lock];
    registerClsNames = mediator.registerClassDict.allKeys.copy;
    [mediator.lock unlock];
    
    for (NSString *clsName in registerClsNames) {
        [mediator.lock lock];
        NSString *key = mediator.registerClassDict[clsName].anyObject;
        ZDMServiceBox *serviceBox = mediator.registerInfoDict[key];
        id serviceObj = mediator.instanceDict[clsName].obj;
        [mediator.lock unlock];
        
        // serviceObj不存在,但cls或其实例响应该方法,则创建实例
        if (
            !serviceObj
            && ([serviceBox.cls instancesRespondToSelector:selector] || [serviceBox.cls respondsToSelector:selector])
            && serviceBox.autoInit
        ) {
            NSString *serviceName = serviceBox.protocolName;
            serviceObj = [self _serviceWithName:serviceName priority:serviceBox.priority needProxyWrap:NO];
        }
        // serviceObj存在,但其不响应此该方法,不过其cls响应该方法,则把cls赋值给serviceObj
        else if (serviceObj && ![serviceObj respondsToSelector:selector] && [serviceBox.cls instancesRespondToSelector:selector]) {
            serviceObj = serviceBox.cls;
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
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    NSMutableOrderedSet<ZDMEventResponder *> *orderSet = mediator.serviceResponderDict[eventKey];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        mediator.serviceResponderDict[eventKey] = orderSet;
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
    
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    NSString *key = zdmStoreKey(serviceName, @(priority));
    [mediator.lock lock];
    ZDMServiceBox *box = mediator.registerInfoDict[key];
    if (!box && priority == ZDMDefaultPriority) {
        NSNumber *prioNum = mediator.priorityDict[serviceName].firstObject;
        NSString *newKey = zdmStoreKey(serviceName, prioNum);
        box = mediator.registerInfoDict[newKey];
    }
    [mediator.lock unlock];
    if (!box) {
        NSLog(@"❌ >>>>> please register a class first");
        return nil;
    }
    
    id serviceInstance = nil;
    NSString *clsName = NSStringFromClass(box.cls);
    if (clsName) {
        serviceInstance = [self _serviceInstaceWithClassName:clsName];
    }
    
    if ((!serviceInstance || object_isClass(serviceInstance)) && box.autoInit) {
        serviceInstance = [self _createInstance:box];
    }
    
    if (!serviceInstance) {
        NSLog(@"❌ >>>>> Finally, the instance object of service: (%@), priority: (%zd) was not found", serviceName, priority);
    }
    
    // prevent crashes
    if (serviceInstance && needWrap) {
        ZDMProxy *proxyValue = [ZDMProxy proxyWithTarget:serviceInstance];
        __weak typeof(box) weakBox = box;
        [proxyValue fixmeWithCallback:^id{
            __strong typeof(weakBox) box = weakBox;
            // 执行到这个闭包说明协议中不都是类方法，需要修改这个属性
            box.isAllClsMethod = NO;
            
            id value = [self _createInstance:box];
            return value;
        }];
        return proxyValue;
    }
    return serviceInstance;
}

+ (id)_createInstance:(ZDMServiceBox *)innerBox {
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
        ZDMContext *context = ZDMOneForAll.shareInstance.context;
        instanceOrCls = [aCls zdm_createInstance:context];
    } else {
        // initialize after store to avoid loop call
        instanceOrCls = [aCls alloc];
        needInitialize = YES;
    }
    
    [self _storeServiceWithStrongObj:instanceOrCls weakObj:nil];
    
    if (needInitialize) {
#if DEBUG
        id temp = instanceOrCls;
#endif
        instanceOrCls = [instanceOrCls init];
#if DEBUG
        NSAssert(instanceOrCls == temp, @"The instance should be equal before and after");
#endif
    }
    
    if ([(NSObject *)instanceOrCls respondsToSelector:@selector(zdm_setup)]) {
        [instanceOrCls zdm_setup];
    }
    
    return instanceOrCls;
}

+ (void)_storeServiceWithName:(NSString *)serviceName serviceBox:(ZDMServiceBox *)box {
    NSNumber *priorityNum = @(box.priority);
    
    NSString *key = zdmStoreKey(serviceName, priorityNum);
    
    __auto_type mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    NSMutableOrderedSet<NSNumber *> *orderSet = mediator.priorityDict[serviceName];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        mediator.priorityDict[serviceName] = orderSet;
    }
#if DEBUG
    if ([orderSet containsObject:priorityNum]) {
        Class aClass = mediator.registerInfoDict[zdmStoreKey(serviceName, priorityNum)].cls;
        NSString *aClassName = NSStringFromClass(aClass);
        NSString *bClassName = NSStringFromClass(box.cls);
        NSAssert4(NO, @"❌ >>>>> service被不同class注册了相同priority,请修改 => priority: %ld, serviceName: %@, aClassName: %@, bClassName: %@", box.priority, serviceName, aClassName, bClassName);
    }
#endif
    [orderSet addObject:priorityNum];
    [orderSet sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];
    
    mediator.registerInfoDict[key] = box;
    [mediator.lock unlock];
    
    NSString *clsName = NSStringFromClass(box.cls);
    if (!clsName) {
        return;
    }
    [mediator.lock lock];
    NSMutableSet<NSString *> *servicePrioritySet = mediator.registerClassDict[clsName];
    if (!servicePrioritySet) {
        servicePrioritySet = [[NSMutableSet alloc] init];
        mediator.registerClassDict[clsName] = servicePrioritySet;
    }
    [servicePrioritySet addObject:key];
    [mediator.lock unlock];
    
    [self _updateProxyTargets];
}

+ (void)_storeServiceWithStrongObj:(id)strongObj weakObj:(id)weakObj {
    if (!strongObj && !weakObj) {
        return;
    }
    
    id obj = strongObj ?: weakObj;
    NSString *clsName = NSStringFromClass([obj class]);
    if (!clsName) {
        return;
    }
    
    __auto_type mediator = ZDMOneForAll.shareInstance;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceDict = mediator.instanceDict;
    
    ZDMServiceItem *item = [ZDMServiceItem itemWithStrongObj:strongObj weakObj:weakObj];
    [mediator.lock lock];
    instanceDict[clsName] = item;
    [mediator.lock unlock];
}

+ (id)_serviceInstaceWithClassName:(NSString *)clsName {
    if (!clsName) {
        return nil;
    }
    
    __auto_type mediator = ZDMOneForAll.shareInstance;
    NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceDict = mediator.instanceDict;
    
    [mediator.lock lock];
    ZDMServiceItem *item = instanceDict[clsName];
    [mediator.lock unlock];
    
    return item.obj;
}

+ (void)_updateProxyTargets {
    NSSet<Class> *clsSet = [self allRegisterClasses];
    [ZDMOneForAll.shareInstance.proxy replaceTargetSet:clsSet];
}

#pragma mark - Property

- (ZDMBroadcastProxy *)proxy {
    // 首次读取时读取全部注册的类.
    // 由于在`+allRegisterClasses`方法内部,当`class`添加到`Set`时会触发类的`+initialize`方法执行,
    // 此时假如`+initialize`中有注册行为,会导致`proxy`再次被调用,出现`proxy`被多次初始化的问题,
    // 所以为了规避此类情况,`proxy`放在`ZDMediator`初始化时一起初始化.
    static BOOL _isFirst = YES;
    
    if (!_isFirst) {
        return _proxy;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _isFirst = NO;
        [_proxy replaceTargetSet:[ZDMOneForAll allRegisterClasses]];
    });
    return _proxy;
}

@end
