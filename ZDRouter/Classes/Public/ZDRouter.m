//
//  ZDRouter.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import "ZDRouter.h"
#import <dlfcn.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import "ZDRCommonProtocol.h"
#import "ZDRInvocation.h"
#import "ZDRContext.h"
#import "ZDRServiceBox.h"
#import "ZDREventResponder.h"

@interface ZDRouter ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, ZDRServiceBox *> *storeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDREventResponder *> *> *serviceResponderMap; ///< 响应事件的Map

@end

@implementation ZDRouter

+ (void)initialize {
    if (self != ZDRouter.class) {
        return;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self _loadRegisterFromMacho];
    });
}

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZDRouter *instance = nil;
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
    _storeMap = @{}.mutableCopy;
    _serviceResponderMap = @{}.mutableCopy;
}

#pragma mark - MachO

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, ZDRServiceBox *> *storeMap = [ZDRouter shareInstance].storeMap;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
#ifdef __LP64__
        const struct mach_header_64 *mhp = (void *)_dyld_get_image_header(i);
#else
        const struct mach_header *mhp = (void *)_dyld_get_image_header(i);
#endif
        
        unsigned long size = 0;
        uint8_t *sectionData = getsectiondata(mhp, SEG_DATA, ZDRouterSectionName, &size);
        if (!sectionData) {
            continue;
        }
        
        struct ZDRMachORegisterKV *items = (struct ZDRMachORegisterKV *)sectionData;
        uint64_t itemCount = size / sizeof(struct ZDRMachORegisterKV);
        for (uint64_t i = 0; i < itemCount; ++i) {
            @autoreleasepool {
                struct ZDRMachORegisterKV item = items[i];
                if (!item.key || !item.value) {
                    continue;
                }
                
                NSString *key = [NSString stringWithUTF8String:item.key];
                Class value = objc_getClass(item.value);
                int autoInit = item.autoInit;
                
                storeMap[key] = ({
                    ZDRServiceBox *box = [[ZDRServiceBox alloc] initWithClass:value];
                    box.autoInit = autoInit == 1;
                    box.isProtocolAllClsMethod = item.allClsMethod == 1;
                    if (item.allClsMethod == 1) {
                        box.strongObj = (id)value; // cast forbid warning
                    }
                    box;
                });
            }
        }
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
    
    ZDRServiceBox *box = [self _createServiceBoxIfNeedWithKey:key];
    box.cls = cls;
}

+ (void)registerServiceName:(NSString *)serviceProtocolName implementClassName:(NSString *)clsName {
    if (!serviceProtocolName) {
        return;
    }
    
    ZDRServiceBox *box = [self _createServiceBoxIfNeedWithKey:serviceProtocolName];
    box.cls = NSClassFromString(clsName);
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj {
    [self manualRegisterService:serviceProtocol implementer:obj weakStore:NO];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj weakStore:(BOOL)weakStore {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    ZDRServiceBox *box = [self _createServiceBoxIfNeedWithKey:key];
    box.autoInit = NO;
    if (weakStore) {
        box.weakObj = obj;
    }
    else {
        box.strongObj = obj;
    }
}

#pragma mark - Get

+ (id)service:(Protocol *)serviceProtocol {
    NSString *key = NSStringFromProtocol(serviceProtocol);
    return [self serviceWithName:key];
}

+ (id)serviceWithName:(NSString *)serviceName {
    if (!serviceName) {
        return nil;
    }
    
    ZDRouter *router = [self shareInstance];
    ZDRServiceBox *box = router.storeMap[serviceName];
    if (!box) {
        NSLog(@"please register class first");
        return nil;
    }
    
    id serviceInstance = box.strongObj ?: box.weakObj;
    if (!serviceInstance && box.autoInit) {
        Class aCls = box.cls;
        if (!aCls) {
            NSLog(@"%d, %s => please register first", __LINE__, __FUNCTION__);
            return nil;
        }
        
        if (box.isProtocolAllClsMethod) {
            serviceInstance = aCls;
        }
        else if ([aCls respondsToSelector:@selector(zdr_createInstance:)]) {
            serviceInstance = [aCls zdr_createInstance:router.context];
        }
        else {
            serviceInstance = [[aCls alloc] init];
        }
        box.strongObj = serviceInstance;
    }
    return serviceInstance;
}

+ (BOOL)removeService:(Protocol *)serviceProtocol autoInitAgain:(BOOL)autoInitAgain {
    if (!serviceProtocol) {
        return NO;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        NSAssert(NO, @"the protocol is nil");
        return NO;
    }
    
    ZDRouter *router = [self shareInstance];
    ZDRServiceBox *serviceBox = router.storeMap[key];
    serviceBox.autoInit = autoInitAgain;
    if (serviceBox.strongObj) {
        serviceBox.strongObj = nil;
        return YES;
    }
    else if (serviceBox.weakObj) {
        serviceBox.weakObj = nil;
        return YES;
    }
    return NO;
}

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol priority:(ZDRPriority)priority eventId:(NSString *)eventId, ... {
    if (!serviceProtocol) {
        return;
    }
    
    va_list args;
    va_start(args, eventId);
    NSString *value = eventId;
    while (value) {
        [self _registerRespondService:serviceProtocol priority:priority eventKey:value];
        value = va_arg(args, NSString *);
    }
    va_end(args);
}

+ (void)registerResponder:(Protocol *)serviceProtocol priority:(ZDRPriority)priority selectors:(SEL)selector, ... {
    if (!serviceProtocol) {
        return;
    }
    
    va_list args;
    va_start(args, selector);
    SEL value = selector;
    while (value) {
        NSString *key = NSStringFromSelector(value);
        [self _registerRespondService:serviceProtocol priority:priority eventKey:key];
        value = va_arg(args, SEL);
    }
    va_end(args);
}

#pragma mark - Dispatch

+ (void)dispatchWithEventId:(NSString *)eventId selAndArgs:(nonnull SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    ZDRouter *router = [self shareInstance];
    NSMutableOrderedSet<ZDREventResponder *> *set = router.serviceResponderMap[eventId];
    for (ZDREventResponder *obj in set) {
        id module = [self serviceWithName:obj.name];
        if (!module) {
            continue;
        };
        
        va_list args;
        va_start(args, selector);
        [ZDRInvocation zd_target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

+ (void)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    ZDRouter *router = [self shareInstance];
    NSString *eventId = NSStringFromSelector(selector);
    NSMutableOrderedSet<ZDREventResponder *> *set = router.serviceResponderMap[eventId];
    for (ZDREventResponder *obj in set) {
        id module = [self serviceWithName:obj.name];
        if (!module) {
            continue;
        };
        
        va_list args;
        va_start(args, selector);
        [ZDRInvocation zd_target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

#pragma mark - Private Method

+ (ZDRServiceBox *)_createServiceBoxIfNeedWithKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    
    ZDRouter *router = [self shareInstance];
    NSMutableDictionary<NSString *, ZDRServiceBox *> *storeDict = router.storeMap;
    ZDRServiceBox *box = storeDict[key];
    if (!box) {
        box = [[ZDRServiceBox alloc] init];
        storeDict[key] = box;
    }
    return box;
}

+ (void)_registerRespondService:(Protocol *)serviceName priority:(ZDRPriority)priority eventKey:(NSString *)eventKey {
    if (!serviceName || !eventKey) {
        return;
    }
    
    ZDRouter *router = [self shareInstance];
    NSMutableOrderedSet<ZDREventResponder *> *orderSet = router.serviceResponderMap[eventKey];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        router.serviceResponderMap[eventKey] = orderSet;
    }
    
    ZDREventResponder *respondModel = ({
        ZDREventResponder *model = [[ZDREventResponder alloc] init];
        model.name = NSStringFromProtocol(serviceName);
        model.priority = priority;
        model;
    });
    
    if ([orderSet containsObject:respondModel]) {
        [orderSet removeObject:respondModel];
    }
    
    __block BOOL hasInsert = NO;
    [orderSet enumerateObjectsUsingBlock:^(ZDREventResponder * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.priority <= priority) {
            [orderSet insertObject:respondModel atIndex:idx];
            hasInsert = YES;
            *stop = YES;
        }
    }];
    if (!hasInsert) {
        [orderSet addObject:respondModel];
    }
}

#pragma mark - Property


@end

//=============================================

#if 0
static void __zdr_machORegisterEmptyFunc(void) {
    // 空实现，只为获取到当前image的Dl_info
}

{
    Dl_info info;
    dladdr((const void*)__zdr_machORegisterEmptyFunc, &info);
    
#ifdef __LP64__
    const struct mach_header_64 *mhp = (struct mach_header_64*)info.dli_fbase;
#else
    const struct mach_header *mhp = (struct mach_header*)info.dli_fbase;
#endif
    unsigned long size = 0;
    uint8_t *sectionData = getsectiondata(mhp, SEG_DATA, ZDRouterSectionName, &size);
    
    NSMutableDictionary<NSString *, Class> *kvContainer = [ZDRModuleCenter shareInstance].protocolWithClassMap;
    
    struct ZDRMachORegisterKV *items = (struct ZDRMachORegisterKV *)sectionData;
    uint64_t itemCount = size / sizeof(struct ZDRMachORegisterKV);
    for (uint64_t i = 0; i < itemCount; ++i) {
        @autoreleasepool {
            struct ZDRMachORegisterKV item = items[i];
            if (!item.key || !item.value) {
                continue;
            }
            
            NSString *key = [NSString stringWithUTF8String:item.key];
            kvContainer[key] = objc_getClass(item.value);
        }
    }
}
#endif
