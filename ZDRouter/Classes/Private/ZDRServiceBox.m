//
//  ZDRServiceBox.m
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import "ZDRServiceBox.h"

@implementation ZDRServiceBox

- (void)dealloc {
    _strongObj = nil;
    _weakObj = nil;
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (instancetype)initWithClass:(Class)cls autoInit:(BOOL)autoInit {
    if (self = [super init]) {
        _cls = cls;
        _autoInit = autoInit;
    }
    return self;
}

#pragma mark - Setter

- (void)setStrongObj:(id<ZDRBaseProtocol>)strongObj {
    if (_strongObj == strongObj) {
        return;
    }
    
    if (strongObj == nil) {
        [self _zdr_willDealloc:_strongObj];
    }
    else if (_strongObj != strongObj) {
        [self _zdr_willDealloc:_strongObj];
    }
    _strongObj = strongObj;
}

- (void)setWeakObj:(id<ZDRBaseProtocol>)weakObj {
    if (_weakObj == weakObj) {
        return;
    }
    
    if (weakObj == nil) {
        [self _zdr_willDealloc:weakObj];
    }
    else if (_weakObj != weakObj) {
        [self _zdr_willDealloc:_weakObj];
    }
    _weakObj = weakObj;
}

#pragma mark - Private

- (void)_zdr_willDealloc:(id<ZDRBaseProtocol>)obj {
    if ([obj respondsToSelector:@selector(zdr_willDealloc)]) {
        [obj zdr_willDealloc];
    }
}

#pragma mark -

- (BOOL)isEqual:(ZDRServiceBox *)other {
    if (other == self) {
        return YES;
    }
    else if (self.strongObj && [self.strongObj isEqual:other.strongObj]) {
        return YES;
    }
    else if (self.weakObj && [self.weakObj isEqual:other.weakObj]) {
        return YES;
    }
    else {
        return [super isEqual:other];
    }
}

- (NSUInteger)hash {
    if (_strongObj) {
        return [_strongObj hash];
    }
    else if (_weakObj) {
        return [_weakObj hash];
    }
    return [super hash];
}

@end
