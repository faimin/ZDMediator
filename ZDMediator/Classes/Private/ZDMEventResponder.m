//
//  ZDMEventResponder.m
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import "ZDMEventResponder.h"

@implementation ZDMEventResponder

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark -

- (BOOL)isEqual:(ZDMEventResponder *)object {
    if (![self isKindOfClass:object.class]) {
        return NO;
    }
    BOOL res = [self.serviceName isEqualToString:object.serviceName];
    return res;
}

- (NSUInteger)hash {
    return self.serviceName.hash ^ self.priority;
}

@end
