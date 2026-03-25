//
//  Mediator+Dispatch.h
//  ZDMediator
//

#import <Foundation/Foundation.h>

// ZDMOneForAll 由 Swift 生成头文件提供
// ObjC Category 扩展 nil-terminated 变参接口

@protocol ZDMCommonProtocol;
@class ZDMContext;

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
