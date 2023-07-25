//
//  ZDDog.m
//  ZDRouter_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDDog.h"
#import <ZDRouter/ZDRouter.h>

ZDRouterRegister(DogProtocol, ZDDog)

@implementation ZDDog

+ (instancetype)zdr_createInstance:(ZDRContext *)context {
    return self.new;
}

- (NSUInteger)age {
    return 2;
}

- (void)foo:(NSInteger)a {
    NSLog(@"%zd", a);
}

- (void)bar:(NSDictionary *)dict {
    NSLog(@"%@", dict);
}

- (BOOL)zdr_handleEvent:(NSInteger)event userInfo:(id)userInfo callback:(ZDRCommonCallback)callback {
    if (event == 200) {
        !callback ? NULL : callback(self.age, @"我是第二个参数");
        return YES;
    }
    return NO;
}

@end
