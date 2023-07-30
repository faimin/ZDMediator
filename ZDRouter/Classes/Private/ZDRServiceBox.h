//
//  ZDRServiceBox.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import <Foundation/Foundation.h>
#import "ZDRCommonProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDRServiceBox : NSObject

@property (nonatomic, unsafe_unretained) Class cls;
@property (nonatomic, strong, nullable) id strongObj;
@property (nonatomic, weak, nullable) id weakObj;
@property (nonatomic, assign) BOOL autoInit;
@property (nonatomic, assign) BOOL isProtocolAllClsMethod;

@property (nonatomic, assign) NSInteger priority;

- (instancetype)initWithClass:(Class _Nullable)cls;

@end

NS_ASSUME_NONNULL_END
