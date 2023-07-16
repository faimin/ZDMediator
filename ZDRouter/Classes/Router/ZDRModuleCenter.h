//
//  ZDRModuleCenter.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDRContext;
@interface ZDRModuleCenter : NSObject

@property (nonatomic, strong, nullable) ZDRContext *context;

+ (instancetype)shareInstance;

- (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls;

/**
 @param obj 内部弱引用这个对象
 */
- (void)registerService:(Protocol *)serviceProtocol implementInstance:(id)obj;

/**
 注册事件与module之间的映射，module不会自动初始化

 @param serviceName 遵守的协议
 @param priority 响应优先级
 @param eventId 事件id
 @param ... 多个type types不能为0，为0会自动结束
 */
- (void)registerRespondService:(Protocol *)serviceName
                      priority:(ZDRPriority)priority
                       eventId:(NSInteger)eventId, ...;
- (void)registerRespondService:(Protocol *)serviceName
                      priority:(ZDRPriority)priority
                     selectors:(SEL)selector, ...;

- (id _Nullable)service:(Protocol *)serviceProtocol;
- (id _Nullable)serviceWithName:(NSString *)serviceName;

- (BOOL)removeService:(Protocol *)serviceProtocol;

/**
 事件分发

 @param eventId 事件id
 @param selector 方法名
 @note 传递的参数，参数个数、类型都要与sel中的类型匹配
 比如 sel = resmethod:(id)abc type:(NSInteger)type tes:(float)dd
 传递的参数应该为 NSObject.new, 1, 2.5
 注意：float 与 int 不能混用，dd 参数需要加小数点，不能为3 ； type 也一样。
     如果sel的第一个参数为整数，则param传nil为跳过，其他参数正常传
 */
- (void)dispatchEventWithId:(NSString *)eventId selectorAndParams:(SEL)selector, ...;

/**
 以方法名作为事件名进行事件分发
 
 @param selector 方法名
 */
- (void)dispatchEventWithSelectorAndParams:(SEL)selector, ...;

@end

//------------------------------------------

@interface ZDRRespondModuleModel : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) ZDRPriority priority;
@property (nonatomic, assign) BOOL autoInit;
@end

//------------------------------------------

#define ZDRProto(proto)\
(NO && ((void)({id<proto> tempObj; tempObj;}), NO), @protocol(proto))


#define ModuleCenter \
[ZDRModuleCenter shareInstance]


#define GetServiceWithClass(proto, clz) \
({ \
    clz *obj = (clz *)[ModuleCenter service:ZDRProto(proto)];\
    if (![obj isKindOfClass:clz.class]) {\
        obj = nil;\
    }\
    obj; \
})


#define GetService(proto) \
((id <proto>)[ModuleCenter service:ZDRProto(proto)])

//------------------------------------------

NS_ASSUME_NONNULL_END
