//
//  ZDRModuleCenter.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import "ZDRModuleCenter.h"
#import <dlfcn.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import "ZDRBaseProtocol.h"
#import "ZDRInvocation.h"
#import "ZDRContext.h"

@interface ZDRModuleCenter ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, Class> *protocolWithClassMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *protocolWithServiceMap; ///< strong表
@property (nonatomic, strong) NSMapTable<NSString *, id> *protocolWithWeakServiceMap; ///< weak表
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDRRespondModuleModel *> *> *protocolWithRespondServiceMap; ///< 响应事件的Map

@end

@implementation ZDRModuleCenter

+ (void)initialize {
    if (self == ZDRModuleCenter.class) {
        [self _loadRegisterFromMacho];
    }
}

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZDRModuleCenter *instance = nil;
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
    _protocolWithClassMap = @{}.mutableCopy;
    _protocolWithServiceMap = @{}.mutableCopy;
    _protocolWithWeakServiceMap = [NSMapTable strongToWeakObjectsMapTable];
    _protocolWithRespondServiceMap = @{}.mutableCopy;
}

#pragma mark - MachO

static void __zdr_machORegisterEmptyFunc(void) {
    // 空实现，只为获取到当前image的Dl_info
}

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, Class> *kvContainer = [ZDRModuleCenter shareInstance].protocolWithClassMap;
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
                kvContainer[key] = objc_getClass(item.value);
            }
        }
    }
    
#if 0
    
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
#endif
}

#pragma mark - Public Method

- (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls {
    if (!serviceProtocol) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    self.protocolWithClassMap[key] = cls;
}

- (void)registerService:(Protocol *)serviceProtocol implementInstance:(id)obj {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    [self.protocolWithWeakServiceMap setObject:obj forKey:key];
}

- (void)registerRespondService:(Protocol *)serviceName priority:(ZDRPriority)priority eventId:(NSInteger)eventId, ... {
    if (!serviceName) {
        return;
    }
    
    va_list args;
    va_start(args, eventId);
    NSInteger value = eventId;
    while (value) {
        [self _registerRespondService:serviceName priority:priority eventKey:@(value).stringValue];
        value = va_arg(args, NSInteger);
    }
    va_end(args);
}

- (void)registerRespondService:(Protocol *)serviceName priority:(ZDRPriority)priority selectors:(SEL)selector, ... {
    if (!serviceName) {
        return;
    }
    
    va_list args;
    va_start(args, selector);
    SEL value = selector;
    while (value) {
        NSString *key = NSStringFromSelector(value);
        [self _registerRespondService:serviceName priority:priority eventKey:key];
        value = va_arg(args, SEL);
    }
    va_end(args);
}

- (id)service:(Protocol *)serviceProtocol {
    NSString *key = NSStringFromProtocol(serviceProtocol);
    return [self serviceWithName:key];
}

- (id)serviceWithName:(NSString *)serviceName {
    if (!serviceName) {
        return nil;
    }
    
    id serviceInstance = self.protocolWithServiceMap[serviceName];
    if (!serviceInstance) {
        serviceInstance = [self.protocolWithWeakServiceMap objectForKey:serviceName];
    }
    if (!serviceInstance) {
        Class cls = self.protocolWithClassMap[serviceName];
        if (!cls) {
            NSAssert(NO, @"please register first");
            return nil;
        }
        
        if (class_conformsToProtocol(cls, @protocol(ZDRBaseProtocol))) {
            serviceInstance = [[cls alloc] initWithContext:self.context];
        }
        else {
            serviceInstance = [[cls alloc] init];
        }
        self.protocolWithServiceMap[serviceName] = serviceInstance;
    }
    return serviceInstance;
}

- (BOOL)removeService:(Protocol *)serviceProtocol {
    if (!serviceProtocol) {
        return NO;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return NO;
    }
    
    __auto_type block = ^(id<ZDRBaseProtocol> obj){
        if ([obj respondsToSelector:@selector(moduleWillDealloc)]) {
            [obj moduleWillDealloc];
        }
    };
    
    id service = self.protocolWithServiceMap[key];
    if (service) {
        block(service);
        self.protocolWithServiceMap[key] = nil;
        return YES;
    }
    
    service = [self.protocolWithWeakServiceMap objectForKey:key];
    if (service) {
        block(service);
        [self.protocolWithWeakServiceMap removeObjectForKey:key];
        return YES;
    }
    return NO;
}

#pragma mark - Dispatch

- (void)dispatchEventWithId:(NSString *)eventId selectorAndParams:(SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    NSMutableOrderedSet <ZDRRespondModuleModel *> *set = self.protocolWithRespondServiceMap[eventId];
    for (ZDRRespondModuleModel *obj in set) {
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

- (void)dispatchEventWithSelectorAndParams:(SEL)selector, ... {
    if (!selector) {
        return;
    }
    
    NSString *eventId = NSStringFromSelector(selector);
    NSMutableOrderedSet <ZDRRespondModuleModel *> *set = self.protocolWithRespondServiceMap[eventId];
    for (ZDRRespondModuleModel *obj in set) {
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

- (void)_registerRespondService:(Protocol *)serviceName priority:(ZDRPriority)priority eventKey:(NSString *)eventKey {
    if (!serviceName || !eventKey) {
        return;
    }
    
    NSMutableOrderedSet<ZDRRespondModuleModel *> *orderSet = self.protocolWithRespondServiceMap[eventKey];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        self.protocolWithRespondServiceMap[eventKey] = orderSet;
    }
    
    ZDRRespondModuleModel *respondModel = ({
        __auto_type model = [[ZDRRespondModuleModel alloc] init];
        model.name = NSStringFromProtocol(serviceName);
        model.priority = priority;
        model;
    });
    
    if ([orderSet containsObject:respondModel]) {
        [orderSet removeObject:respondModel];
    }
    
    __block BOOL hasInsert = NO;
    [orderSet enumerateObjectsUsingBlock:^(ZDRRespondModuleModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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

//==================================

@implementation ZDRRespondModuleModel

- (instancetype)init {
    if (self = [super init]) {
        _autoInit = YES;
    }
    return self;
}

- (BOOL)isEqual:(ZDRRespondModuleModel *)object {
    if (![self isKindOfClass:object.class]) {
        return NO;
    }
    BOOL res = [self.name isEqualToString:object.name];
    return res;
}

- (NSUInteger)hash {
    return self.name.hash;
}

@end
