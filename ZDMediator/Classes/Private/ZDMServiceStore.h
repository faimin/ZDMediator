//
//  ZDMServiceStore.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/7/1.
//

#import <Foundation/Foundation.h>

@class ZDMServiceBox;

NS_ASSUME_NONNULL_BEGIN

@interface ZDMServiceStore : NSObject

//@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, ZDMServiceBox *> *storeMap;
@property (nonatomic, strong, readonly) NSRecursiveLock *lock;

+ (ZDMServiceStore *)shareInstance;

+ (ZDMServiceBox *_Nullable)boxForService:(NSString *)serviceName;

+ (ZDMServiceBox *)boxForService:(NSString *)serviceName createIfNeedWithInjct:(void(^_Nullable)(ZDMServiceBox *))inject;

+ (void)setBox:(ZDMServiceBox *_Nullable)box forService:(NSString *)serviceName;

@end

NS_ASSUME_NONNULL_END
