//
//  ZDRServiceBox.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/22.
//

#import <Foundation/Foundation.h>
#import "ZDRBaseProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDRServiceBox : NSObject

@property (nonatomic, unsafe_unretained) Class cls;
@property (nonatomic, strong, nullable) id<ZDRBaseProtocol> strongObj;
@property (nonatomic, weak, nullable) id<ZDRBaseProtocol> weakObj;
@property (nonatomic, assign) BOOL autoInit;

- (instancetype)initWithClass:(Class)cls autoInit:(BOOL)autoInit;

@end

NS_ASSUME_NONNULL_END
