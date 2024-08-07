//
//  CatProtocol.h
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#ifndef CatProtocol_h
#define CatProtocol_h

#import <Foundation/Foundation.h>
#import <ZDMediator/ZDMCommonProtocol.h>

@protocol CatProtocol <ZDMCommonProtocol>

- (NSString *)name;

+ (NSString *)sex;

@optional

- (NSString *)eatWhatFood;

@end

#endif /* CatProtocol_h */
