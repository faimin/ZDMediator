//
//  ZDMBroadcastProxy.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/9/4.
//

#import "ZDMBroadcastProxy.h"

@interface ZDMBroadcastProxy ()
@property (nonatomic, strong) NSHashTable *weaktable;
@end

@implementation ZDMBroadcastProxy

- (void)dealloc {
    _weaktable = nil;
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (BOOL)isProxy {
    return YES;
}

- (instancetype)initWithHashTable:(NSHashTable *)table {
    _weaktable = table;
    return self;
}

#pragma mark - forward

- (BOOL)respondsToSelector:(SEL)aSelector {
    for (id obj in self.weaktable) {
        if ([obj respondsToSelector:aSelector]) {
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *signature = nil;
    for (id obj in self.weaktable) {
        signature = [obj methodSignatureForSelector:sel];
        if (signature) {
            break;
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    for (id obj in self.weaktable) {
        if ([obj respondsToSelector:invocation.selector]) {
            [invocation invokeWithTarget:obj];
        }
    }
}

@end
