//
//  NSObject+ZDMOnDealloc.m
//  ZDMediator
//
//  Created by Zero_D_Saber on 2025/8/5.
//

#import "NSObject+ZDMOnDealloc.h"
#import <objc/runtime.h>

@interface ZDMTaskBlockExecutor : NSObject

@property (nonatomic, copy, readonly) ZDM_DisposeBlock deallocBlock;
@property (nonatomic, unsafe_unretained, readonly) id realTarget;

- (instancetype)initWithBlock:(ZDM_DisposeBlock)deallocBlock realTarget:(id)realTarget;

@end

@implementation ZDMTaskBlockExecutor

- (void)dealloc {
    if (nil != self.deallocBlock) {
        self.deallocBlock(self.realTarget);
        _deallocBlock = nil;
    }
}

- (instancetype)initWithBlock:(ZDM_DisposeBlock)deallocBlock realTarget:(id)realTarget {
    if (self = [super init]) {
        self->_deallocBlock = [deallocBlock copy];
        self->_realTarget = realTarget;
    }
    return self;
}

@end

#pragma mark - ZDMOnDealloc

@implementation NSObject (ZDMOnDealloc)

- (void)zdm_onDealloc:(ZDM_DisposeBlock)deallocBlock {
    if (!deallocBlock) return;
    
    NSMutableArray *deallocBlocks = objc_getAssociatedObject(self, _cmd);
    if (!deallocBlocks) {
        deallocBlocks = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, _cmd, deallocBlocks, OBJC_ASSOCIATION_RETAIN);
    }
    
    ZDMTaskBlockExecutor *blockExecutor = [[ZDMTaskBlockExecutor alloc] initWithBlock:deallocBlock realTarget:self];
    [deallocBlocks addObject:blockExecutor];
}

@end
