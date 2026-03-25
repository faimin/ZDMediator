//  ZDMediator.h
//  ZDMediator 0.5.0
//  核心 ObjC 类型通过此头文件暴露；Swift 类型（Mediator、MediatorContext 等）
//  通过编译器自动生成的模块接口暴露，无需手动 import。

#ifndef ZDMediator_h
#define ZDMediator_h

#import "ZDMediatorDefine.h"
#import "ZDMProxy.h"
#import "ZDMBroadcastProxy.h"

// ObjC 调用宏（ZDMGetService 系列）定义在 ZDMediatorDefine.h 中
// Swift 类型（ZDMOneForAll / ZDMContext 等）由编译器通过 @objc(ZDMOneForAll) 暴露
// Mediator+Dispatch.h 在 Private 目录，通过 ObjC target cSettings headerSearchPath 可访问

#endif /* ZDMediator_h */
