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

/// initialize method of module
///
/// - Parameter context: context information
+ (instancetype)zdm_createInstance:(ZDMContext *_Nullable)context;

/// called when it is about to be released
- (void)zdm_willDispose;

/// common method to communicate with other modules
///
/// - Parameters:
///   - event: event ID
///   - userInfo: any info
///   - callback: event callback
- (BOOL)zdm_handleEvent:(NSInteger)event
               userInfo:(id _Nullable)userInfo
               callback:(ZDMCommonCallback _Nullable)callback
    NS_SWIFT_UNAVAILABLE("ZDMCommonCallback not available");

@end

NS_ASSUME_NONNULL_END

#endif /* ZDMCommonProtocol_h */
