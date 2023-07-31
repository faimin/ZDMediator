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

//-------------------------1 V 1------------------------------

struct ZDRMachO1V1RegisterKV {
    const char *key;
    const char *value;
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
};

#ifndef ZDRouter1V1SectionName
#define ZDRouter1V1SectionName "__ZDRKV_1V1"
#endif

// 【Usage】:
//  ZDRouterRegisterManual(protocolName, AViewController, 1, 0)
#ifndef ZDRouter1V1RegisterManual
#define ZDRouter1V1RegisterManual(protocol_name, cls, auto_init, protocol_all_cls_method) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouter1V1SectionName))) \
static struct ZDRMachO1V1RegisterKV ZDRKV_##protocol_name_##cls = { \
    .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
    .value = (NO && ((void)[cls class], NO), #cls), \
    .autoInit = (int)(auto_init), \
    .allClsMethod = (int)(protocol_all_cls_method), \
};
#endif

#ifndef ZDRouter1V1Register
#define ZDRouter1V1Register(protocol_name, cls) \
ZDRouter1V1RegisterManual(protocol_name, cls, 1, 0)
#endif

//-------------------------1 V many------------------------------

struct ZDRMachO1VMRegisterKV {
    const char *key;
    const char *value;
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
    const int priority;
};

#ifndef ZDRouter1VMSectionName
#define ZDRouter1VMSectionName "__ZDRKV_1VM"
#endif

// 【Usage】:
//  ZDRouter1VMRegisterManual(protocolName, Class, 100, 1, 0)
#ifndef ZDRouter1VMRegisterManual
#define ZDRouter1VMRegisterManual(protocol_name, cls, _priority, auto_init, protocol_all_cls_method) \
__attribute__((no_sanitize_address)) __attribute__((used, section(SEG_DATA "," ZDRouter1VMSectionName))) \
static struct ZDRMachO1VMRegisterKV ZDRKV_OTM_##protocol_name_##cls = { \
    .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
    .value = (NO && ((void)[cls class], NO), #cls), \
    .autoInit = (int)(auto_init), \
    .allClsMethod = (int)(protocol_all_cls_method), \
    .priority = (int)(_priority), \
};
#endif

#ifndef ZDRouter1VMRegister
#define ZDRouter1VMRegister(protocol_name, cls, _priority) \
ZDRouter1VMRegisterManual(protocol_name, cls, _priority, 1, 0)
#endif

#endif /* ZDRouterDefine_h */
