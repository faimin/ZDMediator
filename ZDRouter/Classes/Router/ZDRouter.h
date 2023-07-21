//
//  ZDRouter.h
//  ZDRouter
//
//  Created by Zero.D.Saber on 2023/7/16.
//

#import <Foundation/Foundation.h>
#import "ZDRouterDefine.h"
#import "ZDRContext.h"

NS_ASSUME_NONNULL_BEGIN

@class ZDRContext;
@interface ZDRouter : NSObject

@property (nonatomic, strong, nullable) ZDRContext *context;

+ (instancetype)shareInstance;

- (void)registerService:(Protocol *)serviceProtocol implementClass:(Class)cls;

/**
 @param obj 对象
 @param weakStore 是否弱引用obj对象，默认是YES
 */
- (void)registerService:(Protocol *)serviceProtocol implementInstance:(id)obj weakStore:(BOOL)weakStore;
- (void)registerService:(Protocol *)serviceProtocol implementInstance:(id)obj;

/**
 注册事件与module之间的映射，module不会自动初始化

 @param serviceName 遵守的协议
 @param priority 响应优先级
 @param eventId 事件id
 @param ... 多个eventId eventId不能为0，为0会自动结束
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
 @param ... 可变参数
 */
- (void)dispatchEventWithSelectorAndParams:(SEL)selector, ...;

@end

//------------------------------------------

//#define ZDRProto(proto) \
//(NO && ((void)({id<proto> tempObj; tempObj;}), NO), @protocol(proto))


#define Router \
[ZDRouter shareInstance]


#define GetService(proto) \
((id <proto>)[[ZDRouter shareInstance] service:@protocol(proto)])


#define GetServiceWithClass(proto, clz) \
({ \
    clz *obj = (clz *)[[ZDRouter shareInstance] service:@protocol(proto)]; \
    if (!obj || ![obj isKindOfClass:clz.class]) { \
        obj = nil; \
    } \
    obj; \
})

//------------------------------------------

NS_ASSUME_NONNULL_END
