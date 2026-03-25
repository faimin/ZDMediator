//  ZDMediatorDefine.h
//  ZDMediator 0.5.0 - Breaking Change: ZDMMachoKVEntry 从 5 字段简化为 3 字段

#ifndef ZDMediatorDefine_h
#define ZDMediatorDefine_h

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

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
// Breaking Change (0.5.0): 简化为无参 block，与 Swift 版本保持一致
typedef id (^ZDMCommonCallback)(void);
#pragma clang diagnostic pop

//-------------------------Macho Section------------------------------

/// Macho section 数据格式（0.5.0 Breaking Change：从 5 字段简化为 3 字段）
/// priority 从 zdm_priority() 获取，isAllClassMethods 运行时检测
typedef struct {
    const char * _Nonnull protocol_name;  // 8 bytes
    const char * _Nonnull class_name;     // 8 bytes
    int32_t      auto_init;               // 4 bytes（1=autoInit, 0=manualInit）
    int32_t      _padding;                // 4 bytes（显式对齐，total=24 bytes）
} ZDMMachoKVEntry;

#ifndef ZDMediatorOFASectionName
#define ZDMediatorOFASectionName "__ZDMKV_OFA"
#endif

/// 自动注册宏（autoInit=YES，首次 service() 调用时自动创建实例）
#ifndef ZDMediatorOFARegister
#define ZDMediatorOFARegister(protocol_name, cls)                               \
    __attribute__((no_sanitize_address))                                         \
    __attribute__((used, section(SEG_DATA "," ZDMediatorOFASectionName)))        \
    static const ZDMMachoKVEntry ZDMKV_OFA_##protocol_name##_##cls = {          \
        .protocol_name = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
        .class_name    = (NO && ((void)[cls class], NO), #cls),                 \
        .auto_init     = 1,                                                      \
        ._padding      = 0,                                                      \
    };
#endif

/// 手动注册宏（autoInit=NO，需手动调用 manualRegisterService:）
#ifndef ZDMediatorOFARegisterManual
#define ZDMediatorOFARegisterManual(protocol_name, cls)                          \
    __attribute__((no_sanitize_address))                                         \
    __attribute__((used, section(SEG_DATA "," ZDMediatorOFASectionName)))        \
    static const ZDMMachoKVEntry ZDMKV_OFA_Manual_##protocol_name##_##cls = {   \
        .protocol_name = (NO && ((void)@protocol(protocol_name), NO), #protocol_name), \
        .class_name    = (NO && ((void)[cls class], NO), #cls),                 \
        .auto_init     = 0,                                                      \
        ._padding      = 0,                                                      \
    };
#endif

/// 1:1 注册宏（等同于 ZDMediatorOFARegister，priority 由 +zdm_priority 决定）
#ifndef ZDMediator1V1Register
#define ZDMediator1V1Register(protocol_name, cls) \
    ZDMediatorOFARegister(protocol_name, cls)
#endif

//-------------------Service Getter Macros-------------------

/// 获取 protocol 对应的服务实例（priority=0，默认最高优先级回退）
#ifndef ZDMGetService
#define ZDMGetService(protocol_name) \
    ((id<protocol_name>)[[ZDMOneForAll class] service:@protocol(protocol_name) priority:0])
#endif

/// 获取指定 priority 的服务实例
#ifndef ZDMGetServiceWithPriority
#define ZDMGetServiceWithPriority(protocol_name, priority) \
    ((id<protocol_name>)[[ZDMOneForAll class] service:@protocol(protocol_name) priority:(priority)])
#endif

/// 只从缓存获取，不触发自动初始化
#ifndef ZDMGetServiceFromCache
#define ZDMGetServiceFromCache(protocol_name) \
    ((id<protocol_name>)[[ZDMOneForAll class] serviceWithName:NSStringFromProtocol(@protocol(protocol_name)) \
                                                      priority:0 \
                                                 onlyFromCache:YES])
#endif

/// 通过 class 直接获取（绕过协议查找，返回已注册的类方法实例）
#ifndef ZDMGetServiceWithClass
#define ZDMGetServiceWithClass(cls_name) \
    ([[ZDMOneForAll class] serviceWithName:NSStringFromClass([cls_name class]) priority:0])
#endif

#endif /* ZDMediatorDefine_h */
