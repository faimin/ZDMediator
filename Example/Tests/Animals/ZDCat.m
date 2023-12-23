//
//  ZDCat.m
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDCat.h"
#import <ZDMediator/ZDMediator.h>

// ZDMediator1V1Register(CatProtocol, ZDCat)
ZDMediator1VMRegister(ZDMCommonProtocol, ZDCat, 1)

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
