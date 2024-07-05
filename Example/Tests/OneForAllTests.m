//
//  OneForAllTests.m
//  ZDMediator_Tests
//
//  Created by Zero.D.Saber on 2024/7/4.
//  Copyright © 2024 8207436. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ZDMediator;
#import "CatProtocol.h"
#import "DogProtocol.h"
#import "AnimalProtocol.h"
#import "ZDCat.h"
#import "ZDClassProtocol.h"

@interface OneForAllTests : XCTestCase

@end

@implementation OneForAllTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    __auto_type cat = [ZDCat new];
    [ZDMOneForAll manualRegisterService:@protocol(CatProtocol) implementer:cat];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    [self measureBlock:^{
        [ZDMOneForAll _loadRegisterFromMacho];
    }];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        BOOL catResult1 = [GetService(AnimalProtocol) zdm_handleEvent:100 userInfo:@{} callback:^id(NSString *x) {
            return @[ x ];
        }];
    }];
}

- (void)test1 {
    BOOL catResult1 = [GetService(AnimalProtocol) zdm_handleEvent:100 userInfo:@{} callback:^id(NSString *x) {
        return @[ x ];
    }];
    XCTAssertTrue(catResult1);
    
    NSString *sex = [GetService(CatProtocol) sex];
    XCTAssertNil(sex);
    
    //----------------------------------
    
    BOOL dogResult1 = [GetServiceWithPriority(AnimalProtocol, 1) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertTrue(dogResult1);
    
    BOOL dogResult2 = [GetService(DogProtocol) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y) {
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        XCTAssertEqual(x, 2);
        return a;
    }];
    XCTAssertFalse(dogResult2);
    
    NSArray *dogResult3 = [GetService(ZDClassProtocol) foo:@[ @1, @2 ] bar:@[ @3, @4, @5 ]];
    XCTAssertEqual(dogResult3.count, 5);
}

- (void)test2 {
    NSString *sex = [GetService(CatProtocol) sex];
    NSString *name = [GetService(CatProtocol) name];
    XCTAssertEqual(sex, @"M");
    XCTAssertEqual(name, @"animal - cat");
}

- (void)testDispatch {
    NSArray *names = [ZDMOneForAll dispatchWithProtocol:@protocol(AnimalProtocol) selAndArgs:@selector(animalName), nil];
    XCTAssertGreaterThanOrEqual(names.count, 2);
}

@end
