//
//  ZD1VMRouter.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/30.
//

#import "ZD1VMRouter.h"
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import "ZDRCommonProtocol.h"
#import "ZDRInvocation.h"
#import "ZDRContext.h"
#import "ZDRServiceBox.h"
#import "ZDREventResponder.h"

@interface ZD1VMRouter ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDRServiceBox *> *> *storeMap;
@end

@implementation ZD1VMRouter

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZD1VMRouter *instance = nil;
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
}

#pragma mark - MachO

+ (void)_loadRegisterIfNeed {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self _loadRegisterFromMacho];
    });
}

+ (void)_loadRegisterFromMacho {
    NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDRServiceBox *> *> *storeMap = [ZD1VMRouter shareInstance].storeMap;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; ++i) {
#ifdef __LP64__
        const struct mach_header_64 *mhp = (void *)_dyld_get_image_header(i);
#else
        const struct mach_header *mhp = (void *)_dyld_get_image_header(i);
#endif
        
        unsigned long size = 0;
        uint8_t *sectionData = getsectiondata(mhp, SEG_DATA, ZDRouter1VMSectionName, &size);
        if (!sectionData) {
            continue;
        }
        
        struct ZDRMachO1VMRegisterKV *items = (struct ZDRMachO1VMRegisterKV *)sectionData;
        uint64_t itemCount = size / sizeof(struct ZDRMachO1VMRegisterKV);
        for (uint64_t i = 0; i < itemCount; ++i) {
            @autoreleasepool {
                struct ZDRMachO1VMRegisterKV item = items[i];
                if (!item.key || !item.value) {
                    continue;
                }
                
                NSString *key = [NSString stringWithUTF8String:item.key];
                Class value = objc_getClass(item.value);
                
                NSMutableOrderedSet<ZDRServiceBox *> *orderSet = storeMap[key];
                if (!orderSet) {
                    orderSet = [[NSMutableOrderedSet alloc] initWithCapacity:1];
                    storeMap[key] = orderSet;
                }
                
                ZDRServiceBox *serviceBox = ({
                    ZDRServiceBox *box = [[ZDRServiceBox alloc] initWithClass:value];
                    box.priority = item.priority;
                    box;
                });
                [orderSet addObject:serviceBox];
            }
        }
        
        // sort
        [storeMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableOrderedSet<ZDRServiceBox *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj sortUsingComparator:^NSComparisonResult(ZDRServiceBox * _Nonnull obj1, ZDRServiceBox * _Nonnull obj2) {
                return obj1.priority >= obj2.priority ? NSOrderedAscending : NSOrderedDescending;
            }];
        }];
    }
}

#pragma mark - Public Method

#pragma mark - Set

+ (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls priority:(NSInteger)priority {
    if (!serviceProtocol) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    ZDRServiceBox *box = [[ZDRServiceBox alloc] initWithClass:cls];
    box.priority = priority;
    
    NSMutableOrderedSet<ZDRServiceBox *> *orderSet = [self _createServiceOrderSetIfNeedWithKey:key];
    [self _insertObj:box toOrderSet:orderSet];
}

+ (void)registerServiceName:(NSString *)serviceProtocolName implementClassName:(NSString *)clsName priority:(NSInteger)priority {
    if (!serviceProtocolName) {
        return;
    }
    [self registerService:NSProtocolFromString(serviceProtocolName) implementClass:NSClassFromString(clsName) priority:priority];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj priority:(NSInteger)priority {
    [self manualRegisterService:serviceProtocol implementer:obj priority:priority weakStore:NO];
}

+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj priority:(NSInteger)priority weakStore:(BOOL)weakStore {
    if (!serviceProtocol || !obj) {
        return;
    }
    
    NSString *key = NSStringFromProtocol(serviceProtocol);
    if (!key) {
        return;
    }
    
    ZDRServiceBox *box = [[ZDRServiceBox alloc] init];
    box.autoInit = NO;
    box.priority = priority;
    if (weakStore) {
        box.weakObj = obj;
    }
    else {
        box.strongObj = obj;
    }
    
    NSMutableOrderedSet *orderSet = [self _createServiceOrderSetIfNeedWithKey:key];
    [self _insertObj:box toOrderSet:orderSet];
}

#pragma mark - Get

#pragma mark - Dispatch

+ (void)dispatchWithProtocol:(Protocol *)protocol selAndArgs:(nonnull SEL)selector, ... {
    if (!protocol || !selector) {
        return;
    }
    
    [self _loadRegisterIfNeed];
    
    NSString *protoName = NSStringFromProtocol(protocol);
    ZD1VMRouter *router = [self shareInstance];
    NSMutableOrderedSet<ZDRServiceBox *> *orderSet = router.storeMap[protoName];
    if (!orderSet) {
        return;
    }
    
    for (ZDRServiceBox *obj in orderSet) {
        id module = obj.strongObj ?: obj.weakObj;
        if (!module) {
            id o = nil;
            if ([obj.cls respondsToSelector:@selector(zdr_createInstance:)]) {
                o = [obj.cls zdr_createInstance:router.context];
            }
            else {
                o = [[obj.cls alloc] init];
            }
            obj.strongObj = o;
            module = o;
        };
        
        va_list args;
        va_start(args, selector);
        [ZDRInvocation zd_target:module invokeSelector:selector args:args];
        va_end(args);
    }
}

#pragma mark - Private Method

+ (NSMutableOrderedSet *)_createServiceOrderSetIfNeedWithKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    
    NSMutableDictionary *storeDict = [ZD1VMRouter shareInstance].storeMap;
    NSMutableOrderedSet *orderSet = storeDict[key];
    if (!orderSet) {
        orderSet = [[NSMutableOrderedSet alloc] init];
        storeDict[key] = orderSet;
    }
    return orderSet;
}

+ (void)_insertObj:(ZDRServiceBox *)box toOrderSet:(NSMutableOrderedSet *)orderSet {
    NSInteger priority = box.priority;
    
    __block NSInteger position = NSNotFound;
    [orderSet enumerateObjectsUsingBlock:^(ZDRServiceBox * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.priority <= priority) {
            [orderSet insertObject:box atIndex:idx];
            position = idx;
            *stop = YES;
        }
    }];
    if (position == NSNotFound) {
        [orderSet addObject:box];
    }
}

@end
