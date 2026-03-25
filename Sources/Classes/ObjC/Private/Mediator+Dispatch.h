//
//  Mediator+Dispatch.h
//  ZDMediator
//

#import <Foundation/Foundation.h>

// ZDMOneForAll 前向声明：SPM 中由 ZDMOneForAll+Forward.h 提供完整 @interface；
// CocoaPods 中由 Swift 生成头文件提供；这里用 @class 避免重复定义冲突。
@class ZDMOneForAll;

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
