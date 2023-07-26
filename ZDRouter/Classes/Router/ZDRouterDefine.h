//
//  ZDRouterDefine.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDRouterDefine_h
#define ZDRouterDefine_h

#import <mach-o/loader.h>

typedef NS_ENUM(NSInteger, ZDRPriority) {
    ZDRPriorityLow      = -100,
    ZDRPriorityDefalut  = 0,
    ZDRPriorityHigh     = 100,
};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
// 参数不能为bool类型，会报错
typedef id(^ZDRCommonCallback)() NS_SWIFT_UNAVAILABLE("ZDRCommonCallback not available");
#pragma clang diagnostic pop


struct ZDRMachORegisterKV {
    const char *key;
    const char *value;
    const int manualInit; // 0、1
    const void *imp;
};

#ifndef ZDRouterSectionName
#define ZDRouterSectionName "__ZDRouter_KV"
#endif

// 【Usage】:
//  ZDRouterRegisterManual(protocolName, AViewController, 0)
#ifndef ZDRouterRegisterManual
#define ZDRouterRegisterManual(protocol_name, cls, manual_init) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouterSectionName))) \
static struct ZDRMachORegisterKV ZDRKV_##protocol_name_##cls = { \
    .key = #protocol_name, \
    .value = #cls, \
    .manualInit = (int)(manual_init), \
};
#endif

#define ZDRouterRegisterFunc(protocol_name, cls, manual_init, fn) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouterSectionName))) \
static struct ZDRMachORegisterKV ZDRKV_##protocol_name_##cls = { \
    .key = #protocol_name, \
    .value = #cls, \
    .manualInit = (int)(manual_init), \
    .imp = fn, \
};

#ifndef ZDRouterRegister
#define ZDRouterRegister(protocol_name, cls) \
ZDRouterRegisterManual(protocol_name, cls, 0)
#endif

#endif /* ZDRouterDefine_h */
