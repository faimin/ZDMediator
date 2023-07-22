//
//  ZDRBaseModule.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import "ZDRBaseModule.h"

@implementation ZDRBaseModule
@synthesize zdr_context = _zdr_context;

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (instancetype)initWithZDRContext:(ZDRContext *)context {
    if (self = [super init]) {
        _zdr_context = context;
    }
    return self;
}

- (BOOL)handleEvent:(NSInteger)event userInfo:(id)userInfo callback:(ZDRCommonCallback)callback {
    return NO;
}

- (void)moduleWillDealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end
