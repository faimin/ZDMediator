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

@interface ZDMOneForAll<__covariant S> : NSObject

@property (nonatomic, strong, nullable) ZDMContext *context;

/// singleton
+ (instancetype)shareInstance;

#pragma mark - Set

/// register implementer Class to map
///
/// - Parameters:
///   - serviceProtocol: protocol
///   - priority: priority of service
///   - cls: implementer Class (instance or Class)
+ (void)registerService:(Protocol *)serviceProtocol
               priority:(NSInteger)priority
         implementClass:(Class)cls;

/// register implementer to map manually
///
/// - Parameters:
///   - serviceProtocol: protocol
///   - priority: priority of service
///   - obj: protocol implementer (instance or Class),
///   if obj is a class, the `isAllClsMethod` will be set `true`
///   - weakStore: strong ref or weak ref, default is NO (strong ref)
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                     priority:(NSInteger)priority
                  implementer:(S)obj
                    weakStore:(BOOL)weakStore;
+ (void)manualRegisterService:(Protocol *)serviceProtocol
                  implementer:(S)obj;

#pragma mark - Get

/// get service instance with protocol
///
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: priority
+ (S _Nullable)service:(Protocol *)serviceProtocol priority:(NSInteger)priority;

/// get service instance with protocol name
///
/// - Parameters:
///   - serviceName: protocol of service
///   - priority: priority
+ (S _Nullable)serviceWithName:(NSString *)serviceName priority:(NSInteger)priority;

/// delete service from store map
///
/// - Parameters:
///   - serviceProtocol protocol of service
///   - autoInitAgain whether init again
/// - Returns: whether removed success
+ (BOOL)removeService:(Protocol *)serviceProtocol
             priority:(NSInteger)priority
        autoInitAgain:(BOOL)autoInitAgain;

#pragma mark - Event

/// register event to service module, match with `+dispatchWithEventId:selAndArgs:`
///
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: responder priority, != service priority
///   - eventId: multi event
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                  eventId:(NSString *)eventId, ...;

/// register SEL event to service module, match with `+dispatchWithEventSelAndArgs:`
///
/// - Parameters:
///   - serviceProtocol: protocol of service
///   - priority: reponder priority, != service priority
///   - selector: multi SEL event, end with nil
+ (void)registerResponder:(Protocol *)serviceProtocol
                 priority:(NSInteger)priority
                selectors:(SEL)selector, ...;

#pragma mark - Dispatch

/// dispatch event with serviceName
///
/// 参数类型必须与SEL中的参数类选一一对应。
///
/// float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
///
/// - Parameters:
///   - protocol: service
///   - selector: SEL and multi any type paramters, end with nil
/// - Returns: values of methods result
+ (NSArray<S> *)dispatchWithProtocol:(Protocol *)protocol
                          selAndArgs:(SEL)selector, ...;

/// dispatch event with eventId, match with `+registerResponder:priority:eventId:`
///
/// 参数类型必须与SEL中的参数类选一一对应。
///
/// float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
///
/// - Parameters:
///   - eventId: event id
///   - selector: SEL and multi any type paramters, end with nil
/// - Returns: values of methods result
+ (NSArray<S> *)dispatchWithEventId:(NSString *)eventId
                         selAndArgs:(SEL)selector, ...;

/// dispatch event with SEL as eventId, match with `+registerResponder:priority:selectors:`
///
/// 参数类型必须与SEL中的参数类选一一对应。
///
/// float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
///
/// - Parameters:
///   - selector: SEL and multi any type paramters
/// - Returns: values of methods result
+ (NSArray<S> *)dispatchWithEventSelAndArgs:(SEL)selector, ...;

/// dispatch SEL to registered services if it implement the SEL
///
/// 参数类型必须与SEL中的参数类选一一对应。
///
/// float 与 int 不能混用，浮点数需要加小数点，type也一样。
/// 如果sel的第一个参数为整数，那么param传nil为跳过，其它参数正常传。
///
/// - Parameters:
///   - selector: SEL and multi any type paramters
/// - Returns: return values of methods
+ (NSArray<S> *)dispatchWithSELAndArgs:(SEL)selector, ...;

/// get all initialized objects in mediator
/// store in weakTable
+ (NSHashTable *)allInitializedObjects;

@end

//-------------------Macro BEGIN-----------------------

#pragma mark - Macro
#pragma mark -

#ifndef ZDMGetService
#define ZDMGetService(proto) ZDMGetServiceWithPriority(proto, ZDMDefaultPriority)
#endif

#ifndef ZDMGetServiceWithPriority
#define ZDMGetServiceWithPriority(proto, _priority) ((id<proto>)[ZDMOneForAll service:@protocol(proto) priority:_priority])
#endif

#ifndef ZDMGetServiceWithClass
#define ZDMGetServiceWithClass(proto, _priority, clz)                                  \
  ({                                                                                \
    clz *obj = (clz *)[ZDMOneForAll service:@protocol(proto) priority:_priority];   \
    if (!obj || ![obj isKindOfClass:clz.class]) {                                   \
      obj = nil;                                                                    \
    }                                                                               \
    obj;                                                                            \
  })
#endif

//-------------------Macro END-----------------------

NS_ASSUME_NONNULL_END
