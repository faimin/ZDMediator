//
//  ZDRouter.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/31.
//

#ifndef ZDRouter_h
#define ZDRouter_h

#if __has_include("ZD1V1Router.h")

#import "ZD1V1Router.h"
#import "ZD1VMRouter.h"
#import "ZDRCommonProtocol.h"
#import "ZDRContext.h"
#import "ZDRouterDefine.h"

#elif __has_include(<ZDRouter/ZD1V1Router.h>)

#import <ZDRouter/ZD1V1Router.h>
#import <ZDRouter/ZD1VMRouter.h>
#import <ZDRouter/ZDRCommonProtocol.h>
#import <ZDRouter/ZDRContext.h>
#import <ZDRouter/ZDRouterDefine.h>

#endif

#endif /* ZDRouter_h */
