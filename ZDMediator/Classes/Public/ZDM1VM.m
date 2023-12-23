//
//  ZDM1VM.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/30.
//

#import "ZDM1VM.h"
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMEventResponder.h"
#import "ZDMInvocation.h"
#import "ZDMServiceBox.h"
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>

@interface ZDM1VM ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMServiceBox *> *> *storeMap;

@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation ZDM1VM

#pragma mark - Singleton

+ (ZDM1VM *)shareInstance {
    static ZDM1VM *instance = nil;
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
    _lock.name = @"ZDM1VM_lock";
    _storeMap = @{}.mutableCopy;
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self _loadRegisterFromMacho];
    });
}

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMServiceBox *> *>
    *storeMap = [ZDM1VM shareInstance].storeMap;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
#ifdef __LP64__
        const struct mach_header_64 *mhp = (void *)_dyld_get_image_header(i);
#else
        const struct mach_header *mhp = (void *)_dyld_get_image_header(i);
#endif
        
        unsigned long size = 0;
        uint8_t *sectionData =
        getsectiondata(mhp, SEG_DATA, ZDMediator1VMSectionName, &size);
        if (!sectionData) {
            continue;
        }
        
        struct ZDMMachO1VMRegisterKV *items =
        (struct ZDMMachO1VMRegisterKV *)sectionData;
        uint64_t itemCount = size / sizeof(struct ZDMMachO1VMRegisterKV);
        for (uint64_t i = 0; i < itemCount; ++i) {
            @autoreleasepool {
                struct ZDMMachO1VMRegisterKV item = items[i];
                if (!item.key || !item.value) {
                    continue;
                }
                
                NSString *key = [NSString stringWithUTF8String:item.key];
                Class value = objc_getClass(item.value);
                
                NSMutableOrderedSet<ZDMServiceBox *> *orderSet = storeMap[key];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    storeMap[key] = orderSet;
                }
                
                ZDMServiceBox *serviceBox = ({
                    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:value];
                    box.priority = item.priority;
                    box;
                });
                [orderSet addObject:serviceBox];
            }
        }
        
        // sort
        [storeMap enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSMutableOrderedSet<ZDMServiceBox *> *_Nonnull obj, BOOL *_Nonnull stop) {
            [obj sortUsingComparator:^NSComparisonResult(ZDMServiceBox *_Nonnull obj1, ZDMServiceBox *_Nonnull obj2) {
                return obj1.priority >= obj2.priority ? NSOrderedAscending : NSOrderedDescending;
            }];
        }];
    }
}

#pragma mark - Public Method

#pragma mark - Set

+ (void)registerService:(Protocol *)serviceProtocol
         implementClass:(Class)cls
               priority:(NSInteger)priority {
    if (!serviceProtocol) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    ZDMServiceBox *box = [[ZDMServiceBox alloc] initWithClass:cls];
    box.priority = priority;
    
    NSMutableOrderedSet<ZDMServiceBox *> *orderSet = [self _createServiceOrderSetIfNeedWithKey:key];
    [self _insertObj:box toOrderSet:orderSet];
}

+ (void)registerServiceName:(NSString *)serviceProtocolName
         implementClassName:(NSString *)clsName
                   priority:(NSInteger)priority {
    if (!serviceProtocolName) {
        return;
    }
    [self registerService:NSProtocolFromString(serviceProtocolName)
           implementClass:NSClassFromString(clsName)
                 priority:priority];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                     priority:(NSInteger)priority {
    [self manualRegisterService:serviceProtocol
                    implementer:obj
                       priority:priority
                      weakStore:NO];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                     priority:(NSInteger)priority
                    weakStore:(BOOL)weakStore {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    ZDMServiceBox *box = [[ZDMServiceBox alloc] init];
    box.autoInit = NO;
    box.priority = priority;
    if (weakStore) {
        box.weakObj = obj;
    } else {
        box.strongObj = obj;
    }
    
    NSMutableOrderedSet *orderSet = [self _createServiceOrderSetIfNeedWithKey:key];
    [self _insertObj:box toOrderSet:orderSet];
}

#pragma mark - Get

#pragma mark - Dispatch

+ (void)dispatchWithProtocol:(Protocol *)protocol
                  selAndArgs:(nonnull SEL)selector, ... {
    if (!protocol || !selector) {
        return;
    }
    
    [self _loadRegisterIfNeed];
    
    NSString *protoName = NSStringFromProtocol(protocol);
    ZDM1VM *router = [self shareInstance];
    NSMutableOrderedSet<ZDMServiceBox *> *orderSet = router.storeMap[protoName];
    if (!orderSet) {
        return;
    }
    
    for (ZDMServiceBox *obj in orderSet) {
        id module = obj.strongObj ?: obj.weakObj;
        if (!module) {
            id o = nil;
            if ([obj.cls respondsToSelector:@selector(zdm_createInstance:)]) {
                o = [obj.cls zdm_createInstance:router.context];
            } else {
                o = [[obj.cls alloc] init];
            }
            obj.strongObj = o;
            module = o;
        };
        
        va_list args;
        va_start(args, selector);
        [ZDMInvocation target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

#pragma mark - Private Method

+ (NSMutableOrderedSet *)_createServiceOrderSetIfNeedWithKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    
    NSMutableDictionary *storeMap = [self shareInstance].storeMap;
    __auto_type lock = [self shareInstance].lock;
    [lock lock];
    NSMutableOrderedSet *orderSet = storeMap[key];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        storeMap[key] = orderSet;
    }
    [lock unlock];
    return orderSet;
}

+ (void)_insertObj:(ZDMServiceBox *)box
        toOrderSet:(NSMutableOrderedSet *)orderSet {
    NSInteger priority = box.priority;
    
    __auto_type lock = [self shareInstance].lock;
    [lock lock];
    __block NSInteger position = NSNotFound;
    [orderSet enumerateObjectsUsingBlock:^(ZDMServiceBox *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if (obj.priority <= priority) {
            [orderSet insertObject:box atIndex:idx];
            position = idx;
            *stop = YES;
        }
    }];
    if (position == NSNotFound) {
        [orderSet addObject:box];
    }
    [lock unlock];
}

@end
