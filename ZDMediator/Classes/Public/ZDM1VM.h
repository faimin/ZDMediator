//
//  ZDM1VM.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/30.
//

#import <Foundation/Foundation.h>
#import "ZDMediatorDefine.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDMContext;

/// One-to-many communication
@interface ZDM1VM : NSObject

@property (nonatomic, strong, nullable) ZDMContext *context;

+ (ZDM1VM *)shareInstance;

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

+ (NSArray<id> *)dispatchWithProtocol:(Protocol *)protocol selAndArgs:(SEL)selector, ...;

@end

NS_ASSUME_NONNULL_END
