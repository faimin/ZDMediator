//
//  ZDMServiceItem.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2024/7/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMServiceItem : NSObject

@property (nonatomic, strong, nullable) id strongObj;
@property (nonatomic, weak, nullable) id weakObj;

@property (nonatomic, readonly, nullable) id obj;

+ (instancetype)itemWithStrongObj:(id _Nullable)strongObj weakObj:(id _Nullable)weakObj;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
