//
//  ZDMediator.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/31.
//

#ifndef ZDMediator_h
#define ZDMediator_h

#if __has_include("ZDM1V1.h")

#import "ZDM1V1.h"
#import "ZDM1VM.h"
#import "ZDMCommonProtocol.h"
#import "ZDMContext.h"
#import "ZDMInvocation.h"
#import "ZDMediatorDefine.h"

#elif __has_include(<ZDMediator/ZDM1V1.h>)

#import <ZDMediator/ZDM1V1.h>
#import <ZDMediator/ZDM1VM.h>
#import <ZDMediator/ZDMCommonProtocol.h>
#import <ZDMediator/ZDMContext.h>
#import <ZDMediator/ZDMInvocation.h>
#import <ZDMediator/ZDMediatorDefine.h>

#endif

#endif /* ZDMediator_h */
