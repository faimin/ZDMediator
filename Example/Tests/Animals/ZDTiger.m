//
//  ZDTiger.m
//  ZDMediator_Example
//
//  Created by Zero_D_Saber on 2025/7/31.
//  Copyright © 2025 8207436. All rights reserved.
//

#import "ZDTiger.h"
#import "AnimalProtocol.h"

@interface ZDTiger () <AnimalProtocol>

@end

@implementation ZDTiger

- (instancetype)init {
    if (self = [super init]) {
        //
    }
    return self;
}

- (void)zdm_setup {
    NSLog(@" %s", __PRETTY_FUNCTION__);
}

#pragma mark -

- (NSString *)animalName {
    return @"老虎";
}

- (void)eatFood {
    NSLog(@"老虎吃饭");
}

@end
