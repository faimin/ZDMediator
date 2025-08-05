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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
