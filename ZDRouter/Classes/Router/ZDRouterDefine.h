//
//  ZDRouterDefine.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDRouterDefine_h
#define ZDRouterDefine_h

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
// 参数不能为bool 值， bool值会报错
typedef id(^ZDRCommonCallback)() NS_SWIFT_UNAVAILABLE("ZDRCommonCallback not available");
#pragma clang diagnostic pop


struct ZDRMachORegisterKV {
    char *key;
    char *value;
};

// 【使用】:
//  ZDRouterMachORegister(protocolName, AViewController)
#define ZDRouterSectionName "zdrouter_kv"
#define ZDRouterMachORegister(protocol, cls) \
__attribute((used, section("__DATA, " ## ZDRouterSectionName))) \
static const struct ZDRMachORegisterKV ___ZDRMachORegisterKV_##key##value = (struct ZDRMachORegisterKV){(char *)(&#protocol), (char *)(&#cls)};

//-------------------------------------------------

#endif /* ZDRouterDefine_h */
