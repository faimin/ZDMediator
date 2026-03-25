//
//  ZDMOneForAll+Forward.h
//  ZDMediator
//
//  Forward declarations for ZDMOneForAll (defined in Swift as Mediator with @objc(ZDMOneForAll)).
//  Used by ObjC files that need to call ZDMOneForAll methods without importing ZDMediator-Swift.h
//  (which is only available inside the same SPM target where Swift sources reside).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Forward declaration of ZDMOneForAll — implemented by Mediator.swift via @objc(ZDMOneForAll).
/// Only the methods actually used by ObjC Category implementations are declared here.
@interface ZDMOneForAll : NSObject

/// Singleton accessor (maps to Mediator.shared).
+ (instancetype)shared;

/// Retrieve service instance by name and priority (maps to Mediator.serviceWithName:priority:).
+ (id _Nullable)serviceWithName:(NSString *)name priority:(NSInteger)priority;

/// Register eventId-based responders (called from Mediator+Dispatch.m).
- (void)_registerResponderForProtocol:(Protocol *)serviceProtocol
                              priority:(NSInteger)priority
                              eventIds:(NSArray<NSString *> *)eventIds;

/// Register selector-name-based responders (called from Mediator+Dispatch.m).
- (void)_registerResponderForProtocol:(Protocol *)serviceProtocol
                              priority:(NSInteger)priority
                         selectorNames:(NSArray<NSString *> *)selectorNames;

/// Return ordered service instances for a protocol (called from Mediator+Dispatch.m).
- (NSArray *)_serviceInstancesForProtocol:(Protocol *)protocol;

/// Return ordered service instances for an eventId (called from Mediator+Dispatch.m).
- (NSArray *)_serviceInstancesForEventId:(NSString *)eventId;

/// Return ordered service instances for a selector name acting as eventId.
- (NSArray *)_serviceInstancesForSelectorName:(NSString *)selectorName;

/// Return all service instances that respond to a selector name.
- (NSArray *)_allServiceInstancesRespondingToSelectorName:(NSString *)selectorName;

@end

NS_ASSUME_NONNULL_END
