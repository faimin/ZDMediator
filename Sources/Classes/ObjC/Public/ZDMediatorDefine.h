//
//  ZDMediatorDefine.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDMediatorDefine_h
#define ZDMediatorDefine_h

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

/// 1v1 priority
#ifndef ZDMDefaultPriority
#define ZDMDefaultPriority ((NSInteger)0)
#endif

#if DEBUG
#ifndef ZDMLog
#define ZDMLog(...) NSLog(@"❌❌❌" __VA_ARGS__);
#endif
#else
#ifndef ZDMLog
#define ZDMLog(...)
#endif
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
// 参数不能为bool类型，因为会报错
//typedef id (^ZDMCommonCallback)() NS_SWIFT_UNAVAILABLE("ZDMCommonCallback not available");
typedef id (^ZDMCommonCallback)();
#pragma clang diagnostic pop

//-------------------------One For All------------------------------

struct ZDMMachoOFARegisterKV {
    const char *key;
    const char *value;
    /// 0,1
    const int autoInit;
    /// 0,1
    const int allClsMethod;
    const int priority;
};

#ifndef ZDMediatorOFASectionName
#define ZDMediatorOFASectionName "__ZDMKV_OFA"
#endif

// 【Usage】:
//  ZDMediatorOFARegisterManual(protocolName, Class, 100, true, false)
#ifndef ZDMediatorOFARegisterManual
#define ZDMediatorOFARegisterManual(protocol_name, cls, _priority, auto_init,  \
                                    protocol_all_cls_method)                   \
  __attribute__((no_sanitize_address)) __attribute__((                         \
      used,                                                                    \
      section(                                                                 \
          SEG_DATA                                                             \
          "," ZDMediatorOFASectionName))) static struct ZDMMachoOFARegisterKV  \
      ZDMKV_OFA_##protocol_name##_##cls = {                                    \
          .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
          .value = (NO && ((void)[cls class], NO), #cls),                      \
          .autoInit = (int)(auto_init),                                        \
          .allClsMethod = (int)(protocol_all_cls_method),                      \
          .priority = (int)(_priority),                                        \
      };
#endif

#ifndef ZDMediatorOFARegister
#define ZDMediatorOFARegister(protocol_name, cls, _priority)                   \
  ZDMediatorOFARegisterManual(protocol_name, cls, _priority, true, false)
#endif

#ifndef ZDMediator1V1Register
#define ZDMediator1V1Register(protocol_name, cls)                              \
  ZDMediatorOFARegister(protocol_name, cls, ZDMDefaultPriority)
#endif

#endif /* ZDMediatorDefine_h */
