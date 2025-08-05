//
//  ZDUnrecognizedMethodTest.m
//  ZDMediator_Tests
//
//  Created by Zero_D_Saber on 2025/8/5.
//  Copyright © 2025 8207436. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ZDMediator;
#import "CatProtocol.h"
#import "ZDCat.h"
#import "ZDDog.h"

@interface ZDUnrecognizedMethodTest : XCTestCase

@end

@implementation ZDUnrecognizedMethodTest

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

// 测试方法不识别的异常处理
- (void)testUnrecognizedMethod {
    NSObject *cat = ZDMGetServiceWithPriority(CatProtocol, ZDMDefaultPriority);
    XCTAssertTrue([cat isKindOfClass:ZDCat.class]);
    
    // 是否crash
    NSString *foodName = [ZDMGetServiceWithPriority(CatProtocol, ZDMDefaultPriority) eatWhatFood];
    XCTAssertNil(foodName);
    
    NSObject *dog = ZDMGetServiceWithClass(CatProtocol, ZDMDefaultPriority, ZDDog);
    XCTAssertNil(dog);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
