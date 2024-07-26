//
//  ZDMOneForAll.h
//  ZDMediator
//
//  Created by Zero.D.Saber on 2024/7/2.
//

#import <Foundation/Foundation.h>
#import "ZDMContext.h"
#import "ZDMediatorDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDMOneForAll : NSObject

@property (nonatomic, strong, nullable) ZDMContext *context;

/// singleton
+ (instancetype)shareInstance;

#pragma mark - Set

/// register implementer Class to map
/// @param serviceProtocol protocol
/// @param cls implementer Class (instance or Class)
+ (void)registerService:(Protocol *)serviceProtocol 
               priority:(NSInteger)priority
         implementClass:(Class)cls;

/// manual register implementer to map
/// - Parameters:
///   - serviceProtocol: protocol
///   - priority: priority of service
///   - obj: protocol implementer (instance or Class),
///   if obj is a class, the `isAllClsMethod` will be set `true`
///   - weakStore: strong ref or weak ref, default is NO (strong ref)
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                     priority:(NSInteger)priority
                  implementer:(id)obj
                    weakStore:(BOOL)weakStore;
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(id)obj;

#pragma mark - Get

/// get service instance with protocol
/// - Parameter serviceProtocol: protocol of service
/// - Parameter priority: priority
+ (id _Nullable)service:(Protocol *)serviceProtocol priority:(NSInteger)priority;

/// get service instance with protocol name
/// - Parameter serviceName: protocol of service
/// - Parameter priority: priority
+ (id _Nullable)serviceWithName:(NSString *)serviceName priority:(NSInteger)priority;

/// delete service from store map
/// @param serviceProtocol protocol of service
/// @param autoInitAgain whether init again
+ (BOOL)removeService:(Protocol *)serviceProtocol
             priority:(NSInteger)priority
        autoInitAgain:(BOOL)autoInitAgain;

#pragma mark - Event

/// register event to service module
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: responder priority, != service priority
///   - eventId: multi event
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ...;

/// register SEL event to service module
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: reponder priority, != service priority
///   - selector: multi SEL event, end with nil
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ...;

#pragma mark - Dispatch

/// dispatch event with serviceName
/// @param protocol service
/// @param selector SEL and multi any type paramters, end with nil
///
/// @warning 参数类型必须与SEL中的参数类选一一对应。
///
/// @note float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
+ (NSArray<id> *)dispatchWithProtocol:(Protocol *)protocol
                           selAndArgs:(SEL)selector, ...;

/// dispatch event with eventId
/// @param eventId event id
/// @param selector SEL and multi any type paramters, end with nil
///
/// @warning 参数类型必须与SEL中的参数类型一一对应。
///
/// @note float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
+ (NSArray<id> *)dispatchWithEventId:(NSString *)eventId 
                          selAndArgs:(SEL)selector, ...;

/// dispatch event with SEL event
/// @param selector SEL and multi any type paramters
///
/// @warning 参数类型必须与SEL中的参数类选一一对应。
///
/// @note float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，则param传nil为跳过，其它参数正常传。
+ (NSArray<id> *)dispatchWithEventSelAndArgs:(SEL)selector, ...;

@end

//------------------------------------------

#pragma mark - Macro
#pragma mark -

#ifndef GetService
#define GetService(proto) GetServiceWithPriority(proto, ZDMDefaultPriority)
#endif

#ifndef GetServiceWithPriority
#define GetServiceWithPriority(proto, _priority) ((id<proto>)[ZDMOneForAll service:@protocol(proto) priority:_priority])
#endif

#ifndef GetServiceWithClass
#define GetServiceWithClass(proto, _priority, clz)                                  \
  ({                                                                                \
    clz *obj = (clz *)[ZDMOneForAll service:@protocol(proto) priority:_priority];   \
    if (!obj || ![obj isKindOfClass:clz.class]) {                                   \
      obj = nil;                                                                    \
    }                                                                               \
    obj;                                                                            \
  })
#endif

//------------------------------------------

NS_ASSUME_NONNULL_END
