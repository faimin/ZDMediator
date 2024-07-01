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

@interface ZDMOneForAll ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMServiceBox *> *> *storeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMEventResponder *> *> *serviceResponderMap; ///< 响应事件的Map
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
    _lock = [[NSRecursiveLock alloc] init];
    _lock.name = @"ZDMOneForAll_lock";
    _storeMap = @{}.mutableCopy;
    _serviceResponderMap = @{}.mutableCopy;
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self _loadRegisterFromMacho];
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        printf("读取1V1 macho耗时： %f\n", end - start);
    });
}

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMServiceBox *> *> *storeMap = [ZDMOneForAll shareInstance].storeMap;
    
    __auto_type lock = [self shareInstance].lock;
    
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
#ifdef __LP64__
        const struct mach_header_64 *mhp = (void *)_dyld_get_image_header(i);
#else
        const struct mach_header *mhp = (void *)_dyld_get_image_header(i);
#endif
        
        unsigned long size = 0;
        uint8_t *sectionData =
        getsectiondata(mhp, SEG_DATA, ZDMediatorOFASectionName, &size);
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
                    box.isProtocolAllClsMethod = item.allClsMethod == 1;
                    if (box.isProtocolAllClsMethod) {
                        box.strongObj = (id)value; // cast forbid warning
                    }
                    box;
                });
                
                NSString *key = [NSString stringWithUTF8String:item.key];
                
                [lock lock];
                NSMutableOrderedSet *orderSet = storeMap[key];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    storeMap[key] = orderSet;
                }
                [orderSet addObject:serviceBox];
                [lock unlock];
            }
        }
        
        // sort
        [lock lock];
        [storeMap enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSMutableOrderedSet<ZDMServiceBox *> *_Nonnull obj, BOOL *_Nonnull stop) {
            [obj sortUsingComparator:^NSComparisonResult(ZDMServiceBox *_Nonnull obj1, ZDMServiceBox *_Nonnull obj2) {
                return obj1.priority >= obj2.priority ? NSOrderedAscending : NSOrderedDescending;
            }];
        }];
        [lock unlock];
    }
}

#pragma mark - Public Method

#pragma mark - Set

+ (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls {
    if (!serviceProtocol) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    NSMutableOrderedSet *set = [self _createOrderSetIfNeedWithKey:key];
    
    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:cls];
    [set addObject:box];
}

+ (void)registerServiceName:(NSString *)serviceProtocolName
         implementClassName:(NSString *)clsName {
    if (!serviceProtocolName) {
        return;
    }
    
    [self registerService:NSProtocolFromString(serviceProtocolName)
           implementClass:NSClassFromString(clsName)];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj {
    [self manualRegisterService:serviceProtocol implementer:obj weakStore:NO];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                    weakStore:(BOOL)weakStore {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    NSMutableOrderedSet *set = [self _createOrderSetIfNeedWithKey:key];
    ZDMServiceBox *box = [[ZDMServiceBox alloc] init];
    box.autoInit = NO;
    // 如果手动注册的是类，则认为协议都是类方法
    box.isProtocolAllClsMethod = object_isClass(obj);
    if (weakStore) {
        box.weakObj = obj;
    } else {
        box.strongObj = obj;
    }
    [set addObject:box];
}

#pragma mark - Get

+ (id)service:(Protocol *)serviceProtocol {
    NSString *key = NSStringFromProtocol(serviceProtocol);
    return [self serviceWithName:key];
}

+ (id)serviceWithName:(NSString *)serviceName {
    return [self serviceWithName:serviceName needProxyWrap:YES];
}

+ (id)serviceWithName:(NSString *)serviceName needProxyWrap:(BOOL)needWrap {
    if (!serviceName) {
        return nil;
    }
    
    [self _loadRegisterIfNeed];
    
    ZDMOneForAll *router = [self shareInstance];
    [router.lock lock];
    ZDMServiceBox *box = router.storeMap[serviceName].firstObject;
    [router.lock unlock];
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
        
        if (box.isProtocolAllClsMethod) {
            serviceInstance = aCls;
        } else if ([aCls respondsToSelector:@selector(zdm_createInstance:)]) {
            serviceInstance = [aCls zdm_createInstance:router.context];
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
        autoInitAgain:(BOOL)autoInitAgain {
    if (!serviceProtocol) {
        return NO;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        NSAssert(NO, @"the protocol is nil");
        return NO;
    }
    
    ZDMOneForAll *router = [ZDMOneForAll shareInstance];
    [router.lock lock];
    ZDMServiceBox *serviceBox = router.storeMap[key].firstObject;
    [router.lock unlock];
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
                 priority:(ZDMPriority)priority
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
                 priority:(ZDMPriority)priority
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

+ (void)dispatchWithEventId:(NSString *)eventId
                 selAndArgs:(nonnull SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    ZDMOneForAll *router = [self shareInstance];
    [router.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = router.serviceResponderMap[eventId];
    [router.lock unlock];
    for (ZDMEventResponder *obj in set.copy) {
        // ZDMInvocation中做了安全校验，不需要用proxy包装
        id module = [self serviceWithName:obj.name needProxyWrap:NO];
        if (!module) {
            continue;
        }
        
        va_list args;
        va_start(args, selector);
        [ZDMInvocation target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

+ (void)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    ZDMOneForAll *router = [self shareInstance];
    NSString *eventId = NSStringFromSelector(selector);
    [router.lock lock];
    NSMutableOrderedSet<ZDMEventResponder *> *set = router.serviceResponderMap[eventId];
    [router.lock unlock];
    for (ZDMEventResponder *obj in set.copy) {
        // ZDMInvocation中做了安全校验，不需要用proxy包装
        id module = [self serviceWithName:obj.name needProxyWrap:NO];
        if (!module) {
            continue;
        }
        
        va_list args;
        va_start(args, selector);
        [ZDMInvocation target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

#pragma mark - Private Method

+ (NSMutableOrderedSet *)_createOrderSetIfNeedWithKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    
    ZDMOneForAll *router = [self shareInstance];
    NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMServiceBox *> *> *storeMap = router.storeMap;
    [router.lock lock];
    NSMutableOrderedSet *orderSet = storeMap[key];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
        storeMap[key] = orderSet;
    }
    [router.lock unlock];
    return orderSet;
}

+ (void)_registerRespondService:(Protocol *)serviceName
                       priority:(ZDMPriority)priority
                       eventKey:(NSString *)eventKey {
    if (!serviceName || !eventKey) {
        return;
    }
    
    ZDMOneForAll *router = [self shareInstance];
    NSMutableOrderedSet<ZDMEventResponder *> *orderSet = router.serviceResponderMap[eventKey];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        router.serviceResponderMap[eventKey] = orderSet;
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
    [orderSet enumerateObjectsUsingBlock:^(ZDMEventResponder *_Nonnull obj,
                                           NSUInteger idx, BOOL *_Nonnull stop) {
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

#pragma mark - Property

@end

