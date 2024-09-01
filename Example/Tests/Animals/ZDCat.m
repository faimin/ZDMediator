//
//  ZDCat.m
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDCat.h"
#import <ZDMediator/ZDMediator.h>
#import "AnimalProtocol.h"

ZDMediator1V1Register(AnimalProtocol, ZDCat)
ZDMediator1V1Register(CatProtocol, ZDCat)

@implementation ZDCat

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)zdm_willDispose {
    NSLog(@"小猫要释放了， %@", self);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"创建了小猫");
    }
    return self;
}

#pragma mark - CatProtocol

- (NSString *)name {
    return @"animal - cat";
}

+ (NSString *)sex {
    return @"M";
}

#if 0
- (NSString *)eatWhatFood {
    return @"小鱼";
}
#endif

#pragma mark - AnimalProtocol

- (NSString *)animalName {
    return @"小猫";
}

- (void)eatFood {
    NSLog(@"小猫吃饼干");
}

#pragma mark - ZDMCommonProtocol

- (BOOL)zdm_handleEvent:(NSInteger)event
               userInfo:(id)userInfo
               callback:(ZDMCommonCallback)callback {
    if (event == 100) {
        if (callback) {
            callback(self.name);
        }
        return YES;
    }
    return NO;
}


@end
