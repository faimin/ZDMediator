//
//  ZDRouter.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"
#import "ZDRContext.h"
#import "ZDRModuleCenter.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDRouter : NSObject

+ (instancetype)shareInstance;

#pragma mark -

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
