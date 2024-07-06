//
//  ZDMServiceBox.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import "ZDMServiceBox.h"

@implementation ZDMServiceBox

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (instancetype)initWithClass:(Class)cls {
    if (self = [self init]) {
        _cls = cls;
    }
    return self;
}

@end
