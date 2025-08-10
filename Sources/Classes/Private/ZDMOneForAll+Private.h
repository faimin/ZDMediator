//
//  ZDMOneForAll+Private.h
//  ZDMediator
//
//  Created by Zero_D_Saber on 2025/7/29.
//

#ifndef ZDMOneForAll_Private_h
#define ZDMOneForAll_Private_h

#import "ZDMOneForAll.h"
#import "ZDMServiceBox.h"
#import "ZDMServiceItem.h"
#import "ZDMEventResponder.h"
#import "ZDMLock.h"

@interface ZDMOneForAll ()

/// { key(protocol+priority): ZDMServiceBox }
@property (nonatomic, strong) NSMutableDictionary<NSString *, ZDMServiceBox *> *registerInfoDict;

/// { key(className): [protocol+priority] }
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *registerClsDict;

/// { key(protocol): [priority] }, used to distribute events
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<NSNumber *> *> *priorityDict;

/// { key(className): ZDMServiceItem }, avoid creating multiple instances of a class that adheres to multiple protocols. (避免一个类注册多个协议然后被创建多次)
@property (nonatomic, strong) NSMutableDictionary<NSString *, ZDMServiceItem *> *instanceDict;

/// { key(SEL || eventId): [ZDMEventResponderModel] }, 响应事件的Map
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableOrderedSet<ZDMEventResponder *> *> *serviceResponderDict;

/// Lock abstraction (NSRecursiveLock by default, os_unfair_lock if UNFAIR_LOCK=1)
@property (nonatomic, strong) ZDMLock *lock;

@end

#endif /* ZDMOneForAll_Private_h */
