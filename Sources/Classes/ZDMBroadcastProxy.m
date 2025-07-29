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
@property (nonatomic, strong) NSSet *targetSet;
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
    _targetSet = targetSet;
    return self;
}

- (void)replaceTargetSet:(NSSet *)targetSet {
    _targetSet = targetSet;
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
#if false
    if (!signature) {
        signature = [NSObject instanceMethodSignatureForSelector:@selector(init)];
    }
#endif
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    for (id obj in self.targetSet) {
        SEL selector = invocation.selector;
        if ([obj respondsToSelector:selector]) {
            [invocation invokeWithTarget:obj];
        } else if (object_isClass(obj) && [(Class)obj instancesRespondToSelector:selector]) {
            NSString *clsName = NSStringFromClass((Class)obj);
            ZDMOneForAll *mediator = ZDMOneForAll.shareInstance;
            id serviceInstance = mediator.instanceMap[clsName].obj;
            if (serviceInstance) {
                [invocation invokeWithTarget:serviceInstance];
                continue;
            }
            
            NSString *protocolPriorityKey = mediator.registerClsMap[clsName].anyObject;
            if (!protocolPriorityKey) {
                continue;
            }
            ZDMServiceBox *box = mediator.registerInfoMap[protocolPriorityKey];
            // intilize service mediatory
            serviceInstance = [ZDMOneForAll serviceWithName:box.protocolName priority:box.priority];
            if (serviceInstance) {
                [invocation invokeWithTarget:serviceInstance];
            }
        }
    }
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"❌ - doesNotRecognizeSelector: %@", NSStringFromSelector(aSelector));
}

@end
