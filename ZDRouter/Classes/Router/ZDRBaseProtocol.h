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

@property (nonatomic, strong, readonly) ZDRContext *context;

/**
 module初始化方法
 
 @param context 上下文
 */
- (instancetype)initWithContext:(ZDRContext *_Nullable)context;

@optional
/**
 模块间通信
 
 @param event 每个模块可以自己定义枚举
 @param userInfo 传递的参数
 @param callback 执行回调
 */
- (BOOL)handleEvent:(NSInteger)event userInfo:(id _Nullable)userInfo callback:(ZDRCommonCallback _Nullable)callback NS_SWIFT_UNAVAILABLE("ZDRCommonCallback not available");

/**
 模块即将释放
 */
- (void)moduleWillDealloc;

@end

NS_ASSUME_NONNULL_END

#endif /* ZDRModuleBaseProtocol_h */
