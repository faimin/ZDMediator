//
//  NSObject+ZDMOnDealloc.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2025/8/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ZDM_DisposeBlock)(id _Nullable realTarget);

@interface NSObject (ZDMOnDealloc)

- (void)zdm_onDealloc:(ZDM_DisposeBlock)deallocBlock;

@end

NS_ASSUME_NONNULL_END
