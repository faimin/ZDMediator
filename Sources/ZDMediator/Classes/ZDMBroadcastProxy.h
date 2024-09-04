//
//  ZDMBroadcastProxy.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/9/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMBroadcastProxy<__covariant TargetType> : NSProxy

- (instancetype)initWithHashTable:(NSHashTable *)table;

@end

NS_ASSUME_NONNULL_END
