//
//  ZDMProxy.m
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/1/7.
//

#import "ZDMProxy.h"
#import <objc/runtime.h>
#import "ZDMConst.h"

@interface ZDMProxy ()
@property (nonatomic, copy, nullable) ZDMFixCallback callback;
@end

@implementation ZDMProxy

- (void)dealloc {
    _target = nil;
    _callback = nil;
}

- (instancetype)initWithTarget:(id)target {
    _target = target;
    return self;
}

+ (instancetype)proxyWithTarget:(id)target {
    return [[ZDMProxy alloc] initWithTarget:target];
}

#pragma mark - Fix

- (void)fixmeWithCallback:(ZDMFixCallback)callback {
    _callback = callback;
}

#pragma mark - Forward Message

- (id)forwardingTargetForSelector:(SEL)selector {
    if (!_target || !selector) {
        return nil;
    }
    
    // 如果不是实例方法则尝试调用类方法，都不成功则返回nil
    if ([_target respondsToSelector:selector]) {
        return _target;
    } else if ([[_target class] respondsToSelector:selector]) {
        return [_target class];
    } else if (
        object_isClass(_target)
        && [(Class)_target instancesRespondToSelector:selector]
    ) {
#if !ASSERTDISABLE
        NSAssert2(NO, @"❎ >>>>> %@ 遵守的协议中不全是类方法，请您修改注册设置。SEL：%@", NSStringFromClass([_target class]), NSStringFromSelector(selector));
#endif
        // 容错处理
        if (self.callback) {
            id newTarget = self.callback();
            if ([newTarget respondsToSelector:selector]) {
                return newTarget;
            }
        }
    }
    
    [NSNotificationCenter.defaultCenter postNotificationName:ZDMUnrecognizedMethodNotification object:nil userInfo:@{
        @"class": [NSString stringWithUTF8String:object_getClassName(_target)],
        @"selector": NSStringFromSelector(@selector(selector)) ?: @"",
        @"source": @"ZDMProxy",
    }];
    
#if DEBUG
    NSLog(@"❎ >>>>> target: %@ don't recognized selector：%@", _target, NSStringFromSelector(selector));
#if !ASSERTDISABLE
    NSAssert2(NO, @"❎ >>>>> target: %@ don't recognized selector：%@", _target, NSStringFromSelector(selector));
#endif
#endif
    
    return nil;
}

/// 转发到这一步一般都是由于`forwardingTargetForSelector:`返回nil
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *signature = nil;
    if (_target && sel) {
        signature = [_target methodSignatureForSelector:sel];
        if (!signature) {
            signature = [NSObject instanceMethodSignatureForSelector:@selector(init)];
        }
    }
    return signature;
}

/// 转发消息,一般只有在出现`doesNotRecognizeSelector:`情况时才会执行到这个方法,此时直接返回nil
- (void)forwardInvocation:(NSInvocation *)invocation {
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}

#pragma mark - NSObject Protocol

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}

- (Class)superclass {
    return [_target superclass];
}

- (Class)class {
    return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}

- (BOOL)isProxy {
    return YES;
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}

@end
