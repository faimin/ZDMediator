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
