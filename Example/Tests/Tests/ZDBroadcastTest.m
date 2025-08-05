//
//  ZDBroadcastTest.m
//  ZDMediator_Tests
//
//  Created by Zero_D_Saber on 2025/8/5.
//  Copyright © 2025 8207436. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ZDMediator;
#import "ZDCat.h"
#import "ZDDog.h"

@interface ZDBroadcastTest : XCTestCase

@end

@implementation ZDBroadcastTest

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

- (void)testBroadcastWithProxy {
//    __auto_type dog = [ZDDog new];
//    [ZDMOneForAll manualRegisterService:@protocol(DogProtocol) implementer:dog];
    
    __auto_type proxy = (ZDMBroadcastProxy<ZDMCommonProtocol> *)ZDMOneForAll.shareInstance.proxy;
    XCTAssertTrue([proxy respondsToSelector:@selector(zdm_handleEvent:userInfo:callback:)], @"Proxy should response to zdm_handleEvent:userInfo:callback:");
    // result只是最后一个结果
    BOOL result = [proxy zdm_handleEvent:100 userInfo:@{@"a": @"aaaaa"} callback:^id{
        return @(YES);
    }];
    XCTAssertTrue(result, @"Broadcast should succeed");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
