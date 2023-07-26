//
//  ZDREventResponder.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import "ZDREventResponder.h"

@implementation ZDREventResponder

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark -

- (BOOL)isEqual:(ZDREventResponder *)object {
    if (![self isKindOfClass:object.class]) {
        return NO;
    }
    BOOL res = [self.name isEqualToString:object.name];
    return res;
}

- (NSUInteger)hash {
    return self.name.hash ^ self.priority;
}

@end
