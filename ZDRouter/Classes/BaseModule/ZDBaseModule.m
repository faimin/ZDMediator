//
//  ZDBaseModule.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import "ZDBaseModule.h"

@implementation ZDBaseModule
@synthesize context = _context;

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (instancetype)initWithContext:(ZDRContext *)context {
    if (self = [super init]) {
        _context = context;
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
