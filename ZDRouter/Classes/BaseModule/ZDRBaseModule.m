//
//  ZDRBaseModule.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import "ZDRBaseModule.h"

@implementation ZDRBaseModule

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)zdr_willDispose {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

+ (instancetype)zdr_createInstance:(ZDRContext *)context {
    __auto_type obj = [[self alloc] init];
    return obj;
}

- (BOOL)handleEvent:(NSInteger)event userInfo:(id)userInfo callback:(ZDRCommonCallback)callback {
    return NO;
}

@end
