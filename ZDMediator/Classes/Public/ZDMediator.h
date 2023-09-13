//
//  ZDMediator.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/31.
//

#ifndef ZDMediator_h
#define ZDMediator_h

#if __has_include("ZD1V1Router.h")

#import "ZD1V1Router.h"
#import "ZD1VMRouter.h"
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMediatorDefine.h"

#elif __has_include(<ZDMediator/ZD1V1Router.h>)

#import <ZDMediator/ZD1V1Router.h>
#import <ZDMediator/ZD1VMRouter.h>
#import <ZDMediator/ZDMCommonProtocol.h>
#import <ZDMediator/ZDMContext.h>
#import <ZDMediator/ZDMediatorDefine.h>

#endif

#endif /* ZDMediator_h */
