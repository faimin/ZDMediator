//
//  ZDMLock.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2025/8/4.
//

#import "ZDMLock.h"
#import <os/lock.h>

#ifndef UNFAIR_LOCK
#define UNFAIR_LOCK 0
#endif

@interface ZDMLock ()
#if UNFAIR_LOCK
@property (nonatomic) os_unfair_lock zdlock;
#else
@property (nonatomic, strong) NSRecursiveLock *zdlock;
#endif
@end

@implementation ZDMLock

- (instancetype)init {
    if (self = [super init]) {
#if UNFAIR_LOCK
        _zdlock = OS_UNFAIR_LOCK_INIT;
#else
        _zdlock = [[NSRecursiveLock alloc] init];
        _zdlock.name = @"ZDMediatorLock";
#endif
    }
    return self;
}

- (void)lock {
#if UNFAIR_LOCK
    os_unfair_lock_lock(&_zdlock);
#else
    [self.zdlock lock];
#endif
}

- (void)unlock {
#if UNFAIR_LOCK
    os_unfair_lock_unlock(&_zdlock);
#else
    [self.zdlock unlock];
#endif
}

@end
