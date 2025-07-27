//
//  ZDMBroadcastProxy.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/9/4.
//

#import "ZDMBroadcastProxy.h"

@interface ZDMBroadcastProxy ()
@property (nonatomic, strong) NSHashTable *weakTable;
@end

@implementation ZDMBroadcastProxy

- (void)dealloc {
    _weakTable = nil;
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (BOOL)isProxy {
    return YES;
}

- (instancetype)initWithHashTable:(NSHashTable *)table {
    _weakTable = table;
    return self;
}

#pragma mark - forward

- (BOOL)respondsToSelector:(SEL)aSelector {
    for (id obj in self.weakTable) {
        if ([obj respondsToSelector:aSelector]) {
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *signature = nil;
    for (id obj in self.weakTable) {
        signature = [obj methodSignatureForSelector:sel];
        if (signature) {
            break;
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    for (id obj in self.weakTable) {
        if ([obj respondsToSelector:invocation.selector]) {
            [invocation invokeWithTarget:obj];
        }
    }
}

@end
