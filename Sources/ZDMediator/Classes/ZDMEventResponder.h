//
//  ZDMEventResponder.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZDMEventResponder : NSObject

@property (nonatomic, copy) NSString *serviceName;
@property (nonatomic, assign) NSInteger priority;

@end

NS_ASSUME_NONNULL_END
