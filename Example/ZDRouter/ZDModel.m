//
//  ZDModel.m
//  ZDRouter_Example
//
//  Created by Zero.D.Saber on 2023/7/21.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDModel.h"
#import <ZDRouter/ZDRouter.h>
#import "ZDProtocol.h"

ZDRouterRegister(ZDProtocol, ZDModel)

@interface ZDModel () <ZDProtocol>

@end

@implementation ZDModel
@synthesize name = _name;

- (void)hello {
    NSLog(@"你好");
}

@end
