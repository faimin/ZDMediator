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

typedef NS_ENUM(NSInteger, ZDMPriority) {
    ZDMPriorityLow = -100,
    ZDMPriorityDefalut = 0,
    ZDMPriorityHigh = 100,
};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
// 参数不能为bool类型，会报错
//typedef id (^ZDMCommonCallback)() NS_SWIFT_UNAVAILABLE("ZDMCommonCallback not available");
typedef id (^ZDMCommonCallback)();
#pragma clang diagnostic pop

#ifndef ZDMIGNORE_SELWARNING
#define ZDMIGNORE_SELWARNING(...)                                              \
  _Pragma("clang diagnostic push")                                             \
      _Pragma("clang diagnostic ignored \"-Wundeclared-selector\"")            \
          __VA_ARGS__ _Pragma("clang diagnostic pop")
#endif

//-------------------------1 V 1------------------------------

struct ZDMMachO1V1RegisterKV {
    const char *key;
    const char *value;
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
};

#ifndef ZDMediator1V1SectionName
#define ZDMediator1V1SectionName "__ZDMKV_1V1"
#endif

// 【Usage】:
//  ZDMediatorRegisterManual(protocolName, AViewController, 1, 0)
#ifndef ZDMediator1V1RegisterManual
#define ZDMediator1V1RegisterManual(protocol_name, cls, auto_init,             \
                                    protocol_all_cls_method)                   \
  __attribute__((no_sanitize_address)) __attribute__((                         \
      used,                                                                    \
      section(                                                                 \
          SEG_DATA                                                             \
          "," ZDMediator1V1SectionName))) static struct ZDMMachO1V1RegisterKV  \
      ZDMKV_##protocol_name##_##cls = {                                        \
          .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
          .value = (NO && ((void)[cls class], NO), #cls),                      \
          .autoInit = (int)(auto_init),                                        \
          .allClsMethod = (int)(protocol_all_cls_method),                      \
  };
#endif

#ifndef ZDMediator1V1Register
#define ZDMediator1V1Register(protocol_name, cls)                              \
  ZDMediator1V1RegisterManual(protocol_name, cls, 1, 0)
#endif

//-------------------------1 V many------------------------------

struct ZDMMachO1VMRegisterKV {
    const char *key;
    const char *value;
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
    const int priority;
};

#ifndef ZDMediator1VMSectionName
#define ZDMediator1VMSectionName "__ZDMKV_1VM"
#endif

// 【Usage】:
//  ZDMediator1VMRegisterManual(protocolName, Class, 100, 1, 0)
#ifndef ZDMediator1VMRegisterManual
#define ZDMediator1VMRegisterManual(protocol_name, cls, _priority, auto_init,  \
                                    protocol_all_cls_method)                   \
  __attribute__((no_sanitize_address)) __attribute__((                         \
      used,                                                                    \
      section(                                                                 \
          SEG_DATA                                                             \
          "," ZDMediator1VMSectionName))) static struct ZDMMachO1VMRegisterKV  \
      ZDMKV_OTM_##protocol_name##_##cls = {                                    \
          .key = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
          .value = (NO && ((void)[cls class], NO), #cls),                      \
          .autoInit = (int)(auto_init),                                        \
          .allClsMethod = (int)(protocol_all_cls_method),                      \
          .priority = (int)(_priority),                                        \
      };
#endif

#ifndef ZDMediator1VMRegister
#define ZDMediator1VMRegister(protocol_name, cls, _priority)                   \
  ZDMediator1VMRegisterManual(protocol_name, cls, _priority, 1, 0)
#endif

//-------------------------One For All------------------------------

struct ZDMMachOOFARegisterKV {
    const char *key;
    const char *value;
    const int autoInit;     ///< 0,1
    const int allClsMethod; ///< 0,1
    const int priority;
};

#ifndef ZDMediatorOFASectionName
#define ZDMediatorOFASectionName "__ZDMKV_OFA"
#endif

// 【Usage】:
//  ZDMediatorOFARegisterManual(protocolName, Class, 100, 1, 0)
#ifndef ZDMediatorOFARegisterManual
#define ZDMediatorOFARegisterManual(protocol_name, cls, _priority, auto_init,  \
                                    protocol_all_cls_method)                   \
  __attribute__((no_sanitize_address)) __attribute__((                         \
      used,                                                                    \
      section(                                                                 \
          SEG_DATA                                                             \
          "," ZDMediatorOFASectionName))) static struct ZDMMachOOFARegisterKV  \
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
  ZDMediatorOFARegisterManual(protocol_name, cls, _priority, 1, 0)
#endif

#endif /* ZDMediatorDefine_h */
