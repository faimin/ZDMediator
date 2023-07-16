//
//  ZDRouter.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import "ZDRouter.h"
#import <objc/runtime.h>
#import "ZDRInvocation.h"
#import "ZDRBaseProtocol.h"

@interface ZDRouter ()

@end

@implementation ZDRouter

#pragma mark - Singleton

+ (instancetype)shareInstance {
    static ZDRouter *router = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        router = [[super allocWithZone:NULL] init];
        [router setup];
    });
    return router;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self shareInstance];
}

- (void)setup {

}

#pragma mark - Public method




#pragma mark - private method



@end
