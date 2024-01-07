//
//  ZDMProxy.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/1/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMProxy<__covariant T> : NSProxy

@property (nonatomic, strong, readonly, nullable) T target;

+ (instancetype)proxyWithTarget:(T _Nullable)target;

@end

NS_ASSUME_NONNULL_END
