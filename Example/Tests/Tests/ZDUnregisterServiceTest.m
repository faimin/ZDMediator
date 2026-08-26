//
//  ZDUnregisterServiceTest.m
//  ZDMediator_Tests
//
//  Created by Zero_D_Saber on 2025/8/5.
//  Copyright © 2025 8207436. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ZDMediator;
#import "CatProtocol.h"
#import "ZDCat.h"
#import "AnimalProtocol.h"
#import "ZDTiger.h"

@protocol ZDServiceReplacementProtocol <ZDMCommonProtocol>

- (NSString *)zdm_testServiceName;

@end

@interface ZDOldService : NSObject <ZDServiceReplacementProtocol>
@end

@implementation ZDOldService

- (NSString *)zdm_testServiceName {
    return @"old";
}

@end

@interface ZDNewService : NSObject <ZDServiceReplacementProtocol>
@end

@implementation ZDNewService

- (NSString *)zdm_testServiceName {
    return @"new";
}

@end

@interface ZDUnregisterServiceTest : XCTestCase

@end

@implementation ZDUnregisterServiceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testRemoveService {
    id cat = ZDMGetService(CatProtocol);
    XCTAssertNotNil(cat);
    
    [ZDMOneForAll removeService:@protocol(CatProtocol) priority:ZDMDefaultPriority autoInitAgain:NO];
    XCTAssertNil(ZDMGetService(CatProtocol));
    
    NSString *name = [ZDMGetService(CatProtocol) name];
    XCTAssertNil(name);
}

- (void)testWeakStoreOldInstanceDoesNotRemoveReplacement {
    NSInteger priority = 987654;
    @autoreleasepool {
        ZDTiger *oldTiger = [ZDTiger new];
        [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                                   priority:priority
                                implementer:oldTiger
                                  weakStore:YES];

        ZDTiger *newTiger = [ZDTiger new];
        [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                                   priority:priority
                                implementer:newTiger
                                  weakStore:YES];

        // 模拟导航去重移除旧控制器；旧实例的释放回调不应清理新注册项。
        oldTiger = nil;

        id service = [ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                          priority:priority
                                     onlyFromCache:YES];
        XCTAssertNotNil(service);
        XCTAssertEqualObjects([service animalName], @"老虎");
    }

    // 自动释放池结束后，新实例也释放，当前注册项应被自动清理。
    XCTAssertNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                      priority:priority
                                 onlyFromCache:YES]);
}

- (void)testReplacingServiceKeyWithDifferentClassRemovesOldBroadcastTarget {
#if DEBUG
    XCTSkip(@"同优先级不同类覆盖仅在 Release 配置下允许");
    return;
#endif
    NSInteger priority = 987660;
    ZDOldService *oldService = [ZDOldService new];
    [ZDMOneForAll manualRegisterService:@protocol(ZDServiceReplacementProtocol)
                               priority:priority
                            implementer:oldService
                              weakStore:NO];

    ZDNewService *newService = [ZDNewService new];
    [ZDMOneForAll manualRegisterService:@protocol(ZDServiceReplacementProtocol)
                               priority:priority
                            implementer:newService
                              weakStore:NO];

    // 相同 service key 被新类覆盖后，全量广播不能再遍历旧类实例。
    NSArray *results = [ZDMOneForAll dispatchWithSELAndArgs:@selector(zdm_testServiceName), nil];
    XCTAssertEqualObjects(results, (@[ @"new" ]));

    [ZDMOneForAll removeService:@protocol(ZDServiceReplacementProtocol)
                       priority:priority
                  autoInitAgain:NO];
}

- (void)testWeakStoreSameObjectMultipleProtocolsCleansEachService {
    NSInteger animalPriority = 987655;
    NSInteger catPriority = 987656;
    @autoreleasepool {
        ZDTiger *tiger = [ZDTiger new];
        [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                                   priority:animalPriority
                                implementer:tiger
                                  weakStore:YES];
        [ZDMOneForAll manualRegisterService:@protocol(CatProtocol)
                                   priority:catPriority
                                implementer:tiger
                                  weakStore:YES];

        XCTAssertNotNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                             priority:animalPriority
                                        onlyFromCache:YES]);
        XCTAssertNotNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(CatProtocol))
                                             priority:catPriority
                                        onlyFromCache:YES]);
    }

    // 同一对象的每个 service key 都应独立执行弱引用清理。
    XCTAssertNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                      priority:animalPriority
                                 onlyFromCache:YES]);
    XCTAssertNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(CatProtocol))
                                      priority:catPriority
                                 onlyFromCache:YES]);
}

- (void)testWeakStoreOldInstanceDoesNotRemoveStrongReplacement {
    NSInteger priority = 987659;
    ZDTiger *oldTiger = [ZDTiger new];
    [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                               priority:priority
                            implementer:oldTiger
                              weakStore:YES];

    ZDTiger *newTiger = [ZDTiger new];
    [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                               priority:priority
                            implementer:newTiger
                              weakStore:NO];

    // 强引用替换会废弃旧弱引用 token，旧实例释放后仍须保留新服务。
    oldTiger = nil;
    id service = [ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                      priority:priority
                                 onlyFromCache:YES];
    XCTAssertNotNil(service);
    XCTAssertEqualObjects([service animalName], @"老虎");

    [ZDMOneForAll removeService:@protocol(AnimalProtocol)
                       priority:priority
                  autoInitAgain:NO];
    XCTAssertNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                      priority:priority
                                 onlyFromCache:YES]);
}

- (void)testConcurrentWeakRegistrationsKeepCurrentServiceAfterStaleRelease {
    for (NSInteger index = 0; index < 100; index++) {
        NSInteger priority = 990000 + index;
        ZDTiger *seedTiger = [ZDTiger new];
        [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                                   priority:priority
                                implementer:seedTiger
                                  weakStore:NO];

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_t readyGroup = dispatch_group_create();
        dispatch_semaphore_t startSemaphore = dispatch_semaphore_create(0);
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        NSMutableArray *tigers = [[NSMutableArray alloc] init];
        for (NSInteger tigerIndex = 0; tigerIndex < 8; tigerIndex++) {
            [tigers addObject:[ZDTiger new]];
        }
        for (ZDTiger *tiger in tigers) {
            dispatch_group_enter(readyGroup);
            dispatch_group_async(group, queue, ^{
                dispatch_group_leave(readyGroup);
                dispatch_semaphore_wait(startSemaphore, DISPATCH_TIME_FOREVER);
                [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                                           priority:priority
                                        implementer:tiger
                                          weakStore:YES];
            });
        }
        dispatch_group_wait(readyGroup, DISPATCH_TIME_FOREVER);
        for (NSInteger tigerIndex = 0; tigerIndex < tigers.count; tigerIndex++) {
            dispatch_semaphore_signal(startSemaphore);
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        id service = [ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                          priority:priority
                                     onlyFromCache:YES];
        ZDTiger *currentTiger = nil;
        for (ZDTiger *tiger in tigers) {
            if ([service isEqual:tiger]) {
                currentTiger = tiger;
                break;
            }
        }
        XCTAssertNotNil(currentTiger);

        // 并发注册结束后，任一非当前实例释放都不得清理当前服务。
        for (NSInteger tigerIndex = 0; tigerIndex < tigers.count; tigerIndex++) {
            if (tigers[tigerIndex] != currentTiger) {
                [tigers replaceObjectAtIndex:tigerIndex withObject:NSNull.null];
                id remainingService = [ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(AnimalProtocol))
                                                           priority:priority
                                                      onlyFromCache:YES];
                XCTAssertTrue([remainingService isEqual:currentTiger]);
            }
        }

        [ZDMOneForAll removeService:@protocol(AnimalProtocol)
                           priority:priority
                      autoInitAgain:NO];
    }
}

- (void)testRemovingOneProtocolKeepsSharedClassInstance {
    NSInteger animalPriority = 987657;
    NSInteger catPriority = 987658;
    ZDTiger *tiger = [ZDTiger new];
    [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol)
                               priority:animalPriority
                            implementer:tiger
                              weakStore:YES];
    [ZDMOneForAll manualRegisterService:@protocol(CatProtocol)
                               priority:catPriority
                            implementer:tiger
                              weakStore:YES];

    [ZDMOneForAll removeService:@protocol(AnimalProtocol)
                       priority:animalPriority
                  autoInitAgain:NO];
    XCTAssertNotNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(CatProtocol))
                                         priority:catPriority
                                    onlyFromCache:YES]);

    tiger = nil;
    XCTAssertNil([ZDMOneForAll serviceWithName:NSStringFromProtocol(@protocol(CatProtocol))
                                      priority:catPriority
                                 onlyFromCache:YES]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
