//
//  Mediator+Dispatch.h
//  ZDMediator
//

#import <Foundation/Foundation.h>
#import "ZDMOneForAll+Forward.h"

// ZDMOneForAll 由 ZDMOneForAll+Forward.h 前向声明（SPM 拆目标后无法 import ZDMediator-Swift.h）

NS_ASSUME_NONNULL_BEGIN

@interface ZDMOneForAll (Dispatch)

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ...;

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ...;

#pragma mark - Dispatch

+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol
                       selAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithEventId:(NSString *)eventId
                      selAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithEventSelAndArgs:(SEL)selector, ...;

+ (NSArray *)dispatchWithSELAndArgs:(SEL)selector, ...;

@end

NS_ASSUME_NONNULL_END
