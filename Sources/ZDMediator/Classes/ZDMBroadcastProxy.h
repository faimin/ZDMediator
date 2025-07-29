//
//  ZDMBroadcastProxy.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/9/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMBroadcastProxy : NSProxy

- (instancetype)initWithTargetSet:(NSSet *)targetSet;

- (void)replaceTargetSet:(NSSet *)targetSet;

@end

NS_ASSUME_NONNULL_END
