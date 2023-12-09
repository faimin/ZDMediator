//
//  ZDMContext.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMContext : NSObject

@property (nonatomic, strong) NSDictionary *launchOptions;
@property (nonatomic, strong, nullable) id extraObj;

@end

NS_ASSUME_NONNULL_END
