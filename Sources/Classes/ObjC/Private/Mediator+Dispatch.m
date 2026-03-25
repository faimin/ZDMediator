//
//  Mediator+Dispatch.m
//  ZDMediator
//

#import "ZDMOneForAll+Forward.h"   // 完整 @interface ZDMOneForAll：SPM 中无法 import ZDMediator-Swift.h
#import "Mediator+Dispatch.h"
#import "ZDMInvocation.h"

@implementation ZDMOneForAll (Dispatch)

#pragma mark - Register Event

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ... {
    if (!serviceProtocol) return;
    NSMutableArray<NSString *> *eventIds = [NSMutableArray array];
    va_list args;
    va_start(args, eventId);
    NSString *value = eventId;
    while (value) {
        [eventIds addObject:value];
        value = va_arg(args, NSString *);
    }
    va_end(args);
    [[self shared] _registerResponderForProtocol:serviceProtocol priority:priority eventIds:eventIds];
}

+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ... {
    if (!serviceProtocol) return;
    NSMutableArray<NSString *> *selectorNames = [NSMutableArray array];
    va_list args;
    va_start(args, selector);
    SEL value = selector;
    while (value) {
        [selectorNames addObject:NSStringFromSelector(value)];
        value = va_arg(args, SEL);
    }
    va_end(args);
    [[self shared] _registerResponderForProtocol:serviceProtocol priority:priority selectorNames:selectorNames];
}

#pragma mark - Dispatch
// Option B：ObjC 持有完整 dispatch 循环，Swift 提供有序实例列表
// va_list 在每次循环内独立声明 + va_start/va_end（ARM64 ABI 要求）

+ (NSArray *)dispatchWithProtocol:(Protocol *)protocol
                       selAndArgs:(SEL)selector, ... {
    if (!protocol || !selector) return @[];
    NSArray *targets = [[self shared] _serviceInstancesForProtocol:protocol];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithEventId:(NSString *)eventId
                      selAndArgs:(SEL)selector, ... {
    if (!eventId || !selector) return @[];
    NSArray *targets = [[self shared] _serviceInstancesForEventId:eventId];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithEventSelAndArgs:(SEL)selector, ... {
    if (!selector) return @[];
    NSString *selName = NSStringFromSelector(selector);
    NSArray *targets = [[self shared] _serviceInstancesForSelectorName:selName];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

+ (NSArray *)dispatchWithSELAndArgs:(SEL)selector, ... {
    if (!selector) return @[];
    NSString *selName = NSStringFromSelector(selector);
    NSArray *targets = [[self shared] _allServiceInstancesRespondingToSelectorName:selName];
    NSMutableArray *results = [NSMutableArray array];
    for (id target in targets) {
        va_list args;
        va_start(args, selector);
        id res = [ZDMInvocation target:target invokeSelector:selector args:args];
        va_end(args);
        if (res) [results addObject:res];
    }
    return results.copy;
}

@end
