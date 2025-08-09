//
//  ZDDog.m
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZDDog.h"
#import "ZDClassProtocol.h"
#import <ZDMediator/ZDMediator.h>
#import "AnimalProtocol.h"

ZDMediatorOFARegister(DogProtocol, ZDDog, 10)
ZDMediatorOFARegister(AnimalProtocol, ZDDog, 10)

@implementation ZDDog

+ (NSInteger)zdm_priority {
    return 12345;
}

+ (void)initialize {
    if (self == [ZDDog class]) {
#warning 在initialize中注册会由于递归dispatch_once发生crash
        //[ZDMOneForAll manualRegisterService:@protocol(ZDClassProtocol) implementer:self];
    }
}

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)zdm_willDispose {
    NSLog(@"小狗要释放了， %@", self);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"创建了小狗");
    }
    return self;
}

- (void)zdm_setup {
    NSLog(@" %s", __PRETTY_FUNCTION__);
}

+ (instancetype)zdm_createInstance:(ZDMContext *)context {
    return self.new;
}

+ (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"----> %s", __PRETTY_FUNCTION__);
    return YES;
}

#pragma mark - DogProtocol

- (NSUInteger)age {
    return 2;
}

#pragma mark - AnimalProtocol

- (NSString *)animalName {
    return @"小狗";
}

- (void)eatFood {
    NSLog(@"小狗吃骨头");
}

#pragma mark -

- (void)foo:(NSInteger)a {
    NSLog(@"%zd", a);
}

- (NSString *)bar:(NSDictionary *)dict {
    NSLog(@"%@", dict);
    return [dict.allKeys componentsJoinedByString:@"+"] ?: @"9999999999";
}

#pragma mark - ZDMCommonProtocol

- (BOOL)zdm_handleEvent:(NSInteger)event
               userInfo:(id)userInfo
               callback:(ZDMCommonCallback)callback {
    if (event == 200) {
        !callback ? NULL : callback(self.age, @"我是第二个参数");
        return YES;
    } else if (event == 101) {
        return YES;
    } else if (event == 100) {
        !callback ? NULL : callback(@"小狗");
        return YES;
    } else if (event == 12345) {
        !callback ? NULL : callback(@"12345-12345");
        return YES;
    }
    return NO;
}

@end

@interface ZDDog (ZDClassProtocol) <ZDClassProtocol>

@end

@implementation ZDDog (ZDClassProtocol)

#pragma mark - ZDClassProtocol

+ (NSArray *)foo:(NSArray *)foo bar:(NSArray *)bar {
    return [[NSArray arrayWithArray:foo] arrayByAddingObjectsFromArray:bar];
}

@end
