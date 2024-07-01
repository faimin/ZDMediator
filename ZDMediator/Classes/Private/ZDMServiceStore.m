//
//  ZDMServiceStore.m
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/7/1.
//

#import "ZDMServiceStore.h"
#import "ZDMServiceBox.h"

@interface ZDMServiceStore ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap;
@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation ZDMServiceStore

+ (ZDMServiceStore *)shareInstance {
    static ZDMServiceStore *instance = nil;
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
    _lock.name = @"ZDMStore_lock";
    
    _storeMap = @{}.mutableCopy;
}

#pragma mark - Public

+ (ZDMServiceBox *)boxForService:(NSString *)serviceName {
    if (!serviceName) {
        return nil;
    }
    
    ZDMServiceStore *store = ZDMServiceStore.shareInstance;
    
    [store.lock lock];
    ZDMServiceBox *box = store.storeMap[serviceName];
    [store.lock unlock];
    
    return box;
}

+ (ZDMServiceBox *)boxForService:(NSString *)serviceName createIfNeedWithInjct:(void(^)(ZDMServiceBox *))inject {
    if (!serviceName) {
        return nil;
    }
    
    ZDMServiceStore *store = ZDMServiceStore.shareInstance;
    
    [store.lock lock];
    ZDMServiceBox *box = store.storeMap[serviceName];
    if (!box) {
        box = [[ZDMServiceBox alloc] init];
        !inject ?: inject(box);
        store.storeMap[serviceName] = box;
    }
    [store.lock unlock];
    
    return box;
}

+ (void)setBox:(ZDMServiceBox *)box forService:(NSString *)serviceName {
    if (!serviceName) {
        return;
    }
    
    ZDMServiceStore *store = ZDMServiceStore.shareInstance;
    
    [store.lock lock];
    store.storeMap[serviceName] = box;
    [store.lock unlock];
}

@end
