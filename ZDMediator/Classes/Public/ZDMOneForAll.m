//
//  ZDMOneForAll.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/7/2.
//

#import "ZDMOneForAll.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMEventResponder.h"
#import "ZDMInvocation.h"
#import "ZDMServiceBox.h"
#import "ZDMProxy.h"

static NSString *zdmStoreKey(NSString *serviceName, NSNumber *priority) {
    return [NSString stringWithFormat:@"%@+%@", serviceName, priority];
}

@interface ZDMOneForAll ()

// key(protocol+priority) -> box
@property (nonatomic, strong) NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap;
// key(protocol) -> [priority]
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<NSNumber *> *> *priorityMap;
// 响应事件的Map
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMEventResponder *> *> *serviceResponderMap;
@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation ZDMOneForAll

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZDMOneForAll *instance = nil;
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
    _storeMap = @{}.mutableCopy;
    _priorityMap = @{}.mutableCopy;
    _serviceResponderMap = @{}.mutableCopy;
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self _loadRegisterFromMacho];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        printf("读取one for all macho耗时：%f 毫秒\n", (end - start)*1000);
    });
}

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap = ZDMOneForAll.shareInstance.storeMap;
    NSMutableDictionary<NSString *, NSMutableOrderedSet<NSNumber *> *> *priorityMap = ZDMOneForAll.shareInstance.priorityMap;
    
    __auto_type lock = [self shareInstance].lock;
    
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
        
        struct ZDMMachOOFARegisterKV *items = (struct ZDMMachOOFARegisterKV *)sectionData;
        uint64_t itemCount = size / sizeof(struct ZDMMachOOFARegisterKV);
        for (uint64_t i = 0; i < itemCount; ++i) {
            @autoreleasepool {
                struct ZDMMachOOFARegisterKV item = items[i];
                if (!item.key || !item.value) {
                    continue;
                }
                
                Class value = objc_getClass(item.value);
                __auto_type serviceBox = ({
                    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:value];
                    box.priority = item.priority;
                    box.autoInit = item.autoInit == 1;
                    box.isAllClsMethod = item.allClsMethod == 1;
                    if (box.isAllClsMethod) {
                        box.strongObj = (id)value; // cast forbid warning
                    }
                    box;
                });
                
                NSString *serviceName = [NSString stringWithUTF8String:item.key];
                NSNumber *priorityNum = @(item.priority);
                
                [lock lock];
                NSMutableOrderedSet *orderSet = priorityMap[serviceName];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    priorityMap[serviceName] = orderSet;
                }
#if DEBUG
                if ([orderSet containsObject:priorityNum]) {
                    NSAssert(NO, @"注册了相同priority的类，请修改");
                }
#endif
                [orderSet addObject:priorityNum];
                
                storeMap[zdmStoreKey(serviceName, priorityNum)] = serviceBox;
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
    [self manualRegisterService:serviceProtocol priority:0 implementer:obj weakStore:NO];
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
    // 如果手动注册的是类，则认为协议都是类方法
    box.isAllClsMethod = object_isClass(obj);
    if (weakStore) {
        box.weakObj = obj;
    } else {
        box.strongObj = obj;
    }
    
    [self _storeServiceWithName:serviceName serviceBox:box];
}

#pragma mark Get

+ (id)service:(Protocol *)serviceProtocol priority:(NSInteger)priority {
    NSString *key = NSStringFromProtocol(serviceProtocol);
    return [self serviceWithName:key priority:priority];
}

+ (id)serviceWithName:(NSString *)serviceName priority:(NSInteger)priority {
    return [self _serviceWithName:serviceName priority:priority needProxyWrap:YES];
}

+ (id)_serviceWithName:(NSString *)serviceName priority:(NSInteger)priority needProxyWrap:(BOOL)needWrap {
    if (!serviceName) {
        return nil;
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSString *key = zdmStoreKey(serviceName, @(priority));
    [mediator.lock lock];
    ZDMServiceBox *box = mediator.storeMap[key];
    if (!box && priority == 0) {
        NSNumber *prioNum = mediator.priorityMap[serviceName].firstObject;
        NSString *newKey = zdmStoreKey(serviceName, prioNum);
        box = mediator.storeMap[newKey];
    }
    [mediator.lock unlock];
    if (!box) {
        NSLog(@"❎ >>>>> please register class first");
        return nil;
    }
    
    id serviceInstance = box.strongObj ?: box.weakObj;
    if (!serviceInstance && box.autoInit) {
        Class aCls = box.cls;
        if (!aCls) {
            NSLog(@"❎ >>>>> %d, %s => please register first", __LINE__, __FUNCTION__);
            return nil;
        }
        
        if (box.isAllClsMethod) {
            serviceInstance = aCls;
        } else if ([aCls respondsToSelector:@selector(zdm_createInstance:)]) {
            serviceInstance = [aCls zdm_createInstance:mediator.context];
        } else {
            serviceInstance = [[aCls alloc] init];
        }
        box.strongObj = serviceInstance;
    }
    
    // prevent crashes
    if (serviceInstance && needWrap) {
        ZDMProxy *proxyValue = [ZDMProxy proxyWithTarget:serviceInstance];
        return proxyValue;
    }
    return serviceInstance;
}

+ (BOOL)removeService:(Protocol *)serviceProtocol
             priority:(NSInteger)priority
        autoInitAgain:(BOOL)autoInitAgain {
    if (!serviceProtocol) {
        NSAssert(NO, @"the protocol is nil");
        return NO;
    }
    
    NSString *serviceName = NSStringFromProtocol(serviceProtocol);
    if (!serviceName) {
        NSAssert(NO, @"the protocol name is nil");
        return NO;
    }
    
    ZDMOneForAll *mediator = [ZDMOneForAll shareInstance];
    NSString *key = zdmStoreKey(serviceName, @(priority));
    [mediator.lock lock];
    [mediator.priorityMap[serviceName] removeObject:@(priority)];
    ZDMServiceBox *serviceBox = mediator.storeMap[key];
    [mediator.lock unlock];
    serviceBox.autoInit = autoInitAgain;
    if (serviceBox.strongObj) {
        serviceBox.strongObj = nil;
        return YES;
    } else if (serviceBox.weakObj) {
        serviceBox.weakObj = nil;
        return YES;
    }
    return NO;
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
        [self _registerRespondService:serviceProtocol
                             priority:priority
                             eventKey:value];
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
        [self _registerRespondService:serviceProtocol
                             priority:priority
                             eventKey:key];
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
        ZDMServiceBox *box = mediator.storeMap[key];
        if (!box) {
            continue;
        }
        id module = box.strongObj ?: box.weakObj;
        if (!module) {
            id o = nil;
            if ([box.cls respondsToSelector:@selector(zdm_createInstance:)]) {
                o = [box.cls zdm_createInstance:mediator.context];
            } else {
                o = [[box.cls alloc] init];
            }
            box.strongObj = o;
            module = o;
        };
        
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:module invokeSelector:selector args:args];
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
    
    ZDMOneForAll *mediator = [self shareInstance];
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderMap[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        // ZDMInvocation中做了安全校验，不需要用proxy包装
        id module = [self _serviceWithName:obj.name priority:obj.priority needProxyWrap:NO];
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
    return results;
}

+ (NSArray<id> *)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) {
        return @[];
    }
    
    ZDMOneForAll *mediator = [self shareInstance];
    NSString *eventId = NSStringFromSelector(selector);
    [mediator.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = mediator.serviceResponderMap[eventId];
    [mediator.lock unlock];
    
    NSMutableArray *results = @[].mutableCopy;
    for (ZDMEventResponder *obj in set.copy) {
        // ZDMInvocation中做了安全校验，不需要用proxy包装
        id module = [self _serviceWithName:obj.name priority:obj.priority needProxyWrap:NO];
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
    return results;
}

#pragma mark - Private Method

+ (void)_registerRespondService:(Protocol *)serviceName
                       priority:(ZDMPriority)priority
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
        model.name = NSStringFromProtocol(serviceName);
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
        NSAssert(NO, @"注册了相同优先级的service，请修改优先级");
    }
#endif
    [orderSet addObject:priorityNum];
    [orderSet sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    mediator.storeMap[zdmStoreKey(serviceName, priorityNum)] = box;
    [mediator.lock unlock];
}

@end

