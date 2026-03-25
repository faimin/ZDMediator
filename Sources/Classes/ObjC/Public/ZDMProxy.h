//
//  ZDMProxy.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/1/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^_Nullable ZDMFixCallback)(void);

@interface ZDMProxy<__covariant T> : NSProxy

@property (nonatomic, weak, readonly, nullable) T target;

+ (instancetype)proxyWithTarget:(T _Nullable)target;

// target is class but we need instance, then we transform target to instance
- (void)fixmeWithCallback:(ZDMFixCallback)callback;

@end

NS_ASSUME_NONNULL_END
