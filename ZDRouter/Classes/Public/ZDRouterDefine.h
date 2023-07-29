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
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
};

#ifndef ZDRouterSectionName
#define ZDRouterSectionName "__ZDRouter_KV"
#endif

// 【Usage】:
//  ZDRouterRegisterManual(protocolName, AViewController, 1, 0)
#ifndef ZDRouterRegisterManual
#define ZDRouterRegisterManual(protocol_name, cls, auto_init, protocol_all_cls_method) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouterSectionName))) \
static struct ZDRMachORegisterKV ZDRKV_##protocol_name_##cls = { \
    .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
    .value = #cls, \
    .autoInit = (int)(auto_init), \
    .allClsMethod = (int)protocol_all_cls_method, \
};
#endif

#ifndef ZDRouterRegister
#define ZDRouterRegister(protocol_name, cls) \
ZDRouterRegisterManual(protocol_name, cls, 1, 0)
#endif

#endif /* ZDRouterDefine_h */
