//
//  ZDRContext.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDRContext : NSObject

@property (nonatomic, weak, nullable) UIView *inView;
@property (nonatomic, weak, nullable) UIViewController *inVC;
@property (nonatomic, copy, nullable) NSString *biz;
@property (nonatomic, strong, nullable) id extraObj;

@end

NS_ASSUME_NONNULL_END
