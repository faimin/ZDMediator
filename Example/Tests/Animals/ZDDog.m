//
//  ZDDog.m
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import "ZDDog.h"
#import "ZDClassProtocol.h"
#import <ZDMediator/ZDMediator.h>

ZDMediator1V1Register(DogProtocol, ZDDog)
    ZDMediator1VMRegister(ZDMCommonProtocol, ZDDog, 1)

        @implementation ZDDog

+ (void)initialize {
  if (self == [ZDDog class]) {
    [ZD1V1Router manualRegisterService:@protocol(ZDClassProtocol)
                           implementer:self];
  }
}

+ (instancetype)zdm_createInstance:(ZDMContext *)context {
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

- (BOOL)zdm_handleEvent:(NSInteger)event
               userInfo:(id)userInfo
               callback:(ZDMCommonCallback)callback {
  if (event == 200) {
    !callback ? NULL : callback(self.age, @"我是第二个参数");
    return YES;
  } else if (event == 101) {
    return YES;
  }
  return NO;
}

@end

@interface ZDDog (ZDClassProtocol) <ZDClassProtocol>

@end

@implementation ZDDog (ZDClassProtocol)

+ (NSArray *)foo:(NSArray *)foo bar:(NSArray *)bar {
  return [[NSArray arrayWithArray:foo] arrayByAddingObjectsFromArray:bar];
}

@end
