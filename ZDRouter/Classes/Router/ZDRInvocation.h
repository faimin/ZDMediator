//
//  ZDRInvocation.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDRInvocation<__covariant R : id> : NSObject

+ (R)zd_target:(id)target invokeSelectorWithArgs:(SEL)selector, ...;

+ (R)zd_target:(id)target invokeSelector:(SEL)selector args:(va_list)args;

@end

NS_ASSUME_NONNULL_END
