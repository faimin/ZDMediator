//
//  ZDProtocol.h
//  ZDRouter_Example
//
//  Created by Zero.D.Saber on 2023/7/22.
//  Copyright © 2023 8207436. All rights reserved.
//

#ifndef ZDProtocol_h
#define ZDProtocol_h

@protocol ZDProtocol <NSObject>

@property (nonatomic, strong) NSString *name;

- (void)hello;

@end

#endif /* ZDProtocol_h */
