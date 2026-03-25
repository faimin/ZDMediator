//
//  AnimalProtocol.h
//  ZDMediator_Tests
//
//  Created by Zero_D_Saber on 2024/6/30.
//  Copyright © 2024 8207436. All rights reserved.
//

#ifndef AnimalProtocol_h
#define AnimalProtocol_h

#import <Foundation/Foundation.h>
@import ZDMediator;

@protocol AnimalProtocol <ZDMCommonProtocol>

- (NSString *)animalName;

- (void)eatFood;

@end

#endif /* AnimalProtocol_h */
