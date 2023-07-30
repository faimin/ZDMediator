//
//  ZDCat.m
//  ZDRouter_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDCat.h"
#import <ZDRouter/ZDSingleRouter.h>
#import <ZDRouter/ZDBroadcastRouter.h>

//ZDRouterRegister(CatProtocol, ZDCat)
ZDRouterOneToMoreRegister(ZDRCommonProtocol, ZDCat, 1)

@implementation ZDCat

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)moduleWillDealloc {
    NSLog(@"小猫要释放了， %@", self);
}

- (NSString *)name {
    return @"animal - cat";
}

- (BOOL)zdr_handleEvent:(NSInteger)event userInfo:(id)userInfo callback:(ZDRCommonCallback)callback {
    if (event == 100) {
        if (callback) {
            callback(self.name);
        }
        return YES;
    }
    return NO;
}

@end
