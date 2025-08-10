//
//  ZDMBroadcastProxy.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/9/4.
//

#import "ZDMBroadcastProxy.h"
#import <objc/runtime.h>
#import "ZDMOneForAll+Private.h"
#import "ZDMServiceBox.h"

@interface ZDMBroadcastProxy ()
@property (atomic, strong) id<NSFastEnumeration> targetSet;
@end

@implementation ZDMBroadcastProxy

- (void)dealloc {
    _targetSet = nil;
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)replaceTargetSet:(id<NSFastEnumeration>)targetSet {
    self.targetSet = targetSet;
}

- (BOOL)isProxy {
    return YES;
}

#pragma mark - forward

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    for (id obj in self.targetSet) {
        if ([obj conformsToProtocol:aProtocol]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    for (id obj in self.targetSet) {
        if ([obj respondsToSelector:aSelector]) {
            return YES;
        } else if (object_isClass(obj) && [(Class)obj instancesRespondToSelector:aSelector]) {
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *signature = nil;
    for (id obj in self.targetSet) {
        signature = [obj methodSignatureForSelector:sel];
        if (!signature) {
            // class, but SEL is instance selector
            if (object_isClass(obj)) {
                signature = [(Class)obj instanceMethodSignatureForSelector:sel];
            } else {
                // instance, but SEL is class selector
                Class cls = [obj class];
                if ([cls respondsToSelector:sel]) {
                    signature = [cls methodSignatureForSelector:sel];
                }
            }
        }
        if (signature) {
            break;
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    for (id obj in self.targetSet) {
        SEL selector = invocation.selector;
        if ([obj respondsToSelector:selector]) {
            [invocation invokeWithTarget:obj];
        } else if (object_isClass(obj)) {
            // obj is class, but SEL is instance selector
            if ([(Class)obj instancesRespondToSelector:selector]) {
                [self _executeInstanceMethodWithCls:obj invocation:invocation];
            }
        } else {
            // obj is instance, but SEL is class selector
            Class cls = [obj class];
            if ([cls respondsToSelector:selector]) {
                [invocation invokeWithTarget:cls];
            }
        }
    }
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
#if DEBUG
    NSLog(@"❌ - doesNotRecognizeSelector: %@", NSStringFromSelector(aSelector));
#endif
}

#pragma mark - Private

/// execute instance method for a class, create a instance if it is not exist
- (void)_executeInstanceMethodWithCls:(Class)cls invocation:(NSInvocation *)invocation {
    NSString *clsName = NSStringFromClass(cls);
    if (!clsName) {
        return;
    }
    ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
    [mediator.lock lock];
    id serviceInstance = mediator.instanceDict[clsName].obj;
    [mediator.lock unlock];
    if (serviceInstance && [serviceInstance respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:serviceInstance];
        return;
    }
    
    [mediator.lock lock];
    NSString *protocolPriorityKey = mediator.registerClsDict[clsName].anyObject;
    ZDMServiceBox *box = protocolPriorityKey ? mediator.registerInfoDict[protocolPriorityKey] : nil;
    [mediator.lock unlock];
    if (!box) {
        return;
    }
    if (!box.autoInit) {
        return;
    }
    // intilize service mediatory
    serviceInstance = [ZDMOneForAll serviceWithName:box.protocolName priority:box.priority];
    if (serviceInstance && [serviceInstance respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:serviceInstance];
    }
}

@end
