//
//  ZDMediator.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/31.
//

#ifndef ZDMediator_h
#define ZDMediator_h

#if __has_include("ZDM1V1Router.h")

#import "ZDM1V1Router.h"
#import "ZDM1VMRouter.h"
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMediatorDefine.h"
#import "ZDMInvocation.h"

#elif __has_include(<ZDMediator/ZDM1V1Router.h>)

#import <ZDMediator/ZDM1V1Router.h>
#import <ZDMediator/ZDM1VMRouter.h>
#import <ZDMediator/ZDMCommonProtocol.h>
#import <ZDMediator/ZDMContext.h>
#import <ZDMediator/ZDMediatorDefine.h>
#import <ZDMediator/ZDMInvocation.h>

#endif

#endif /* ZDMediator_h */
