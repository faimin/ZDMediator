//
//  ZDMServiceItem.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/7/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMServiceItem<__covariant T> : NSObject

@property (nonatomic, strong, nullable) T strongObj;
@property (nonatomic, weak, nullable) T weakObj;

@property (nonatomic, readonly, nullable) T obj;

+ (instancetype)itemWithStrongObj:(T _Nullable)strongObj weakObj:(T _Nullable)weakObj;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
