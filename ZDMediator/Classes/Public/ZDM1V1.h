//
//  ZDM1V1.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import "ZDMContext.h"
#import "ZDMediatorDefine.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZDMContext;

/// One-to-one communication
@interface ZDM1V1 : NSObject

@property (nonatomic, strong, nullable) ZDMContext *context;

/// singleton
+ (ZDM1V1 *)shareInstance;

#pragma mark - Set

/// register implementer Class to map
/// @param serviceProtocol protocol
/// @param cls implementer Class (instance or Class)
+ (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls;
+ (void)registerServiceName:(NSString *)serviceProtocolName implementClassName:(NSString *)clsName;

/// manual register implementer to map
/// - Parameters:
///   - serviceProtocol: protocol
///   - obj: protocol implementer (instance or Class),
///   if obj is a class, the `isProtocolAllClsMethod` will be set `true`
///   - weakStore: strong ref or weak ref, default is NO (strong ref)
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj
                    weakStore:(BOOL)weakStore;
+ (void)manualRegisterService:(Protocol *)serviceProtocol implementer:(id)obj;

#pragma mark - Get

/// get service instance with protocol
/// - Parameter serviceProtocol: protocol of service
+ (id _Nullable)service:(Protocol *)serviceProtocol;

/// get service instance with protocol name
/// - Parameter serviceName: protocol of service
+ (id _Nullable)serviceWithName:(NSString *)serviceName;

/// delete service from store map
/// @param serviceProtocol protocol of service
/// @param autoInitAgain whether init again
+ (BOOL)removeService:(Protocol *)serviceProtocol
        autoInitAgain:(BOOL)autoInitAgain;

#pragma mark - Event

/// register number event to service module
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: priority
///   - eventId: multi number event
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(ZDMPriority)priority
                  eventId:(NSString *)eventId, ...;

/// register SEL event to service module
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: priority
///   - selector: multi SEL event, end with nil
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(ZDMPriority)priority
                selectors:(SEL)selector, ...;

/// dispatch event with numbre event
/// @param eventId number event id
/// @param selector SEL and multi any type paramters, end with nil
///
/// @warning 参数类型必须与SEL中的参数类选一一对应。
///
/// @note float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
+ (void)dispatchWithEventId:(NSString *)eventId selAndArgs:(SEL)selector, ...;

/// dispatch event with SEL event
/// @param selector SEL and multi any type paramters
///
/// @warning 参数类型必须与SEL中的参数类选一一对应。
///
/// @note float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，则param传nil为跳过，其它参数正常传。
+ (void)dispatchWithEventSelAndArgs:(SEL)selector, ...;

@end

//------------------------------------------

#pragma mark - Macro
#pragma mark -

#ifndef GetService
#define GetService(proto) ((id<proto>)[ZDM1V1 service:@protocol(proto)])
#endif

#ifndef GetClassService
#define GetClassService(proto) ((id<proto>)[[ZDM1V1 service:@protocol(proto)] class])
#endif

#ifndef GetServiceWithClass
#define GetServiceWithClass(proto, clz)                                        \
  ({                                                                           \
    clz *obj = (clz *)[ZDM1V1 service:@protocol(proto)];                 \
    if (!obj || ![obj isKindOfClass:clz.class]) {                              \
      obj = nil;                                                               \
    }                                                                          \
    obj;                                                                       \
  })
#endif

//------------------------------------------

NS_ASSUME_NONNULL_END
