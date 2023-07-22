//
//  ZDRBaseProtocol.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/15.
//

#ifndef ZDRModuleBaseProtocol_h
#define ZDRModuleBaseProtocol_h

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDRContext;
@protocol ZDRBaseProtocol <NSObject>

@optional
@property (nonatomic, strong, readonly) ZDRContext *zdr_context;

/// 模块初始化方法
/// - Parameter context: 上下文信息
- (instancetype)initWithZDRContext:(ZDRContext *_Nullable)context;

/// 模块即将释放
- (void)zdr_willDealloc;

/// 模块间通信
/// @param event 事件类型
/// @param userInfo 传递的参数
/// @param callback 事件回调
- (BOOL)zdr_handleEvent:(NSInteger)event userInfo:(id _Nullable)userInfo callback:(ZDRCommonCallback _Nullable)callback NS_SWIFT_UNAVAILABLE("ZDRCommonCallback not available");

@end

NS_ASSUME_NONNULL_END

#endif /* ZDRModuleBaseProtocol_h */
