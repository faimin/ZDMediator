//
//  ZDMServiceStore.m
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/7/6.
//

#import "ZDMServiceItem.h"
#import "ZDMCommonProtocol.h"

@implementation ZDMServiceItem

- (void)dealloc {
    _strongObj = nil;
    _weakObj = nil;
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

+ (instancetype)itemWithStrongObj:(id _Nullable)strongObj weakObj:(id _Nullable)weakObj {
    __auto_type item = [[ZDMServiceItem alloc] init];
    item.strongObj = strongObj;
    item.weakObj = weakObj;
    return item;
}

- (void)clear {
    self.strongObj = nil;
    self.weakObj = nil;
}

#pragma mark - Getter

- (id)obj {
    return self.strongObj ?: self.weakObj;
}

#pragma mark - Setter

- (void)setStrongObj:(id<ZDMCommonProtocol>)strongObj {
    if (_strongObj == strongObj) {
        return;
    }
    
    [self _zdm_willRemoveObj:_strongObj];
    _strongObj = strongObj;
}

- (void)setWeakObj:(id<ZDMCommonProtocol>)weakObj {
    if (_weakObj == weakObj) {
        return;
    }
    
    [self _zdm_willRemoveObj:_weakObj];
    _weakObj = weakObj;
}

#pragma mark - Private

- (void)_zdm_willRemoveObj:(id<ZDMCommonProtocol>)obj {
    if (obj && [obj respondsToSelector:@selector(zdm_willDispose)]) {
        [obj zdm_willDispose];
    }
}

@end
