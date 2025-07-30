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
@property (nonatomic, copy) NSSet *targetSet;
@end

@implementation ZDMBroadcastProxy

- (void)dealloc {
    _targetSet = nil;
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (BOOL)isProxy {
    return YES;
}

- (instancetype)initWithTargetSet:(NSSet *)targetSet {
    _targetSet = [targetSet copy];
    return self;
}

- (void)replaceTargetSet:(NSSet *)targetSet {
    self.targetSet = targetSet;
}

#pragma mark - forward

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
        if (!signature && object_isClass(obj)) {
            signature = [(Class)obj instanceMethodSignatureForSelector:sel];
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
        } else if (object_isClass(obj) && [(Class)obj instancesRespondToSelector:selector]) {
            [self _executeInstanceMethodWithCls:obj invocation:invocation];
        }
    }
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"❌ - doesNotRecognizeSelector: %@", NSStringFromSelector(aSelector));
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
    id serviceInstance = mediator.instanceMap[clsName].obj;
    [mediator.lock unlock];
    if (serviceInstance) {
        [invocation invokeWithTarget:serviceInstance];
        return;
    }
    
    [mediator.lock lock];
    NSString *protocolPriorityKey = mediator.registerClsMap[clsName].anyObject;
    ZDMServiceBox *box = protocolPriorityKey ? mediator.registerInfoMap[protocolPriorityKey] : nil;
    [mediator.lock unlock];
    if (!box) {
        return;
    }
    if (!box.autoInit) {
        return;
    }
    // intilize service mediatory
    serviceInstance = [ZDMOneForAll serviceWithName:box.protocolName priority:box.priority];
    if (serviceInstance) {
        [invocation invokeWithTarget:serviceInstance];
    }
}

@end
