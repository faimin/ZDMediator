//
//  ZDMCommonProtocol.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDMCommonProtocol_h
#define ZDMCommonProtocol_h

#import <Foundation/Foundation.h>
#import "ZDMediatorDefine.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDMContext;
@protocol ZDMCommonProtocol <NSObject>

@optional

/// 模块初始化方法
/// - Parameter context: 上下文信息
+ (instancetype)zdm_createInstance:(ZDMContext *_Nullable)context;

/// 即将解除对模块的引用
- (void)zdm_willDispose;

/// 模块间通信
/// @param event 事件类型
/// @param userInfo 传递的参数
/// @param callback 事件回调
- (BOOL)zdm_handleEvent:(NSInteger)event
               userInfo:(id _Nullable)userInfo
               callback:(ZDMCommonCallback _Nullable)callback
    NS_SWIFT_UNAVAILABLE("ZDMCommonCallback not available");

@end

NS_ASSUME_NONNULL_END

#endif /* ZDMCommonProtocol_h */
