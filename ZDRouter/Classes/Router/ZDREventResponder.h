//
//  ZDREventResponder.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDREventResponder : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) ZDRPriority priority;

@end

NS_ASSUME_NONNULL_END
