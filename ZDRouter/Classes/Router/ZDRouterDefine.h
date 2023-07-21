//
//  ZDRouterDefine.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDRouterDefine_h
#define ZDRouterDefine_h

#import <mach-o/loader.h>

/**
 响应优先级 默认defalut
 */
typedef NS_ENUM(NSInteger, ZDRPriority) {
    ZDRPriorityLow      = -100,
    ZDRPriorityDefalut  = 0,
    ZDRPriorityHigh     = 100,
};

// 定义modules 传递消息的回调block类型 无参可以随意传递参数
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
// 参数不能为bool类型，会报错
typedef id(^ZDRCommonCallback)() NS_SWIFT_UNAVAILABLE("ZDRCommonCallback not available");
#pragma clang diagnostic pop


struct ZDRMachORegisterKV {
    const char *key;
    const char *value;
};

// 【Usage】:
//  ZDRouterMachORegister(protocolName, AViewController)
#define ZDRouterSectionName "__ZDRouter_KV"
#define ZDRouterRegister(protocol_name, cls) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouterSectionName))) \
static struct ZDRMachORegisterKV ___ZDRKV_##protocol_name_##cls = { \
    .key = (((void)(NO && ((void)@protocol(protocol_name), NO)), #protocol_name)), \
    .value = (((void)(NO && ((void)cls.class, NO)), #cls)) \
};

//-------------------------------------------------

#endif /* ZDRouterDefine_h */
