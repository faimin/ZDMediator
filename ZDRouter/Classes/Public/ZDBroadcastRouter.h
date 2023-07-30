//
//  ZDBroadcastRouter.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/30.
//

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDRContext;
@interface ZDBroadcastRouter : NSObject

@property (nonatomic, strong, nullable) ZDRContext *context;

+ (instancetype)shareInstance;

+ (void)registerService:(Protocol *)serviceProtocol
         implementClass:(Class)cls
               priority:(NSInteger)priority;
+ (void)registerServiceName:(NSString *)serviceProtocolName
         implementClassName:(NSString *)clsName
                   priority:(NSInteger)priority;

+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                     priority:(NSInteger)priority;
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                     priority:(NSInteger)priority
                    weakStore:(BOOL)weakStore;

+ (void)dispatchWithProtocol:(Protocol *)protocol
                  selAndArgs:(SEL)selector, ...;

@end

NS_ASSUME_NONNULL_END
