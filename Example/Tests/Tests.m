//
//  ZDSingleRouterTests.m
//  ZDSingleRouterTests
//
//  Created by 8207436 on 04/16/2023.
//  Copyright (c) 2023 8207436. All rights reserved.
//

@import XCTest;
@import ZDMediator;
#import "CatProtocol.h"
#import "DogProtocol.h"
#import "AnimalProtocol.h"
#import "ZDClassProtocol.h"
#import "ZDCat.h"
#import "ZDDog.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
    
    __auto_type cat = [ZDCat new];
    [ZDMOneForAll manualRegisterService:@protocol(CatProtocol) implementer:cat];
    
    [ZDMOneForAll registerResponder:@protocol(DogProtocol)
                           priority:ZDMPriorityHigh
                          selectors:@selector(foo:), @selector(bar:), nil];
    
    [ZDMOneForAll registerResponder:@protocol(DogProtocol)
                           priority:ZDMPriorityDefalut
                            eventId:@"100", @"200"];
    [ZDMOneForAll registerResponder:@protocol(CatProtocol)
                           priority:ZDMPriorityDefalut
                            eventId:@"100", @"200"];
}

- (void)tearDown {
    [ZDMOneForAll removeService:@protocol(CatProtocol) priority:0 autoInitAgain:NO];
    
    NSString *name = [GetService(CatProtocol) name];
    XCTAssertNil(name);
    
    // Put teardown code here. This method is called after the invocation of each
    // test method in the class.
    [super tearDown];
}

- (void)testExample {
    BOOL catResult1 = [GetService(CatProtocol) zdm_handleEvent:100 userInfo:@{} callback:^id(NSString *x) {
        return @[ x ];
    }];
    XCTAssertTrue(catResult1);
    
    NSString *sex = [GetService(CatProtocol) sex];
    XCTAssertNotNil(sex);
    
    //----------------------------------
    
    BOOL dogResult1 = [GetService(DogProtocol) zdm_handleEvent:123 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    BOOL dogResult2 = [GetService(DogProtocol) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y) {
        XCTAssertEqual(x, 2);
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
    NSArray *dogResult3 = [GetService(ZDClassProtocol) foo:@[ @1, @2 ] bar:@[ @3, @4, @5 ]];
    XCTAssertEqual(dogResult3.count, 5);
    
    NSString *animalName = [GetServiceWithPriority(AnimalProtocol, 1) animalName];
    XCTAssertTrue([animalName isEqualToString:@"小狗"]);
}

- (void)testWeakStore {
    {
        __auto_type dog = [ZDDog new];
        [ZDMOneForAll manualRegisterService:@protocol(DogProtocol) priority:100 implementer:dog weakStore:YES];
    }
    
    XCTestExpectation *expect = [self expectationWithDescription:@"弱引用测试"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSObject *dog = GetServiceWithPriority(DogProtocol, 100);
        NSLog(@"%@", dog);
        XCTAssertNil(dog);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

- (void)testPriority {
    NSString *clsName = NSStringFromClass([GetServiceWithPriority(AnimalProtocol, 1) class]);
    XCTAssertTrue([clsName isEqualToString:@"ZDDog"]);
    
    BOOL res = [GetServiceWithPriority(AnimalProtocol, 1) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertTrue(res);
}

- (void)testUnrecognizedMethod {
    NSObject *cat = GetServiceWithPriority(CatProtocol, 0);
    XCTAssertTrue([NSStringFromClass([cat class]) isEqualToString:@"ZDCat"]);
    
    // 是否crash
    NSString *foodName = [GetServiceWithPriority(CatProtocol, 0) eatWhatFood];
    XCTAssertNil(foodName);
    
    NSObject *dog = GetServiceWithClass(CatProtocol, 0, ZDDog);
    XCTAssertNil(dog);
}

- (void)testDispatch {
    ZDMIGNORE_SELWARNING(
                         __unused NSArray *fooRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         __unused NSArray *fooRes2 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         __unused NSArray *barRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(bar:), @{@"name" : @"zero.d.saber"}];
                         
                         [ZDMOneForAll dispatchWithEventId:@"100" selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 200, @{@100 : @"100"}, nil];
                         )
    
    
    {
        NSMutableArray *results1 = @[].mutableCopy;
        [ZDMOneForAll dispatchWithProtocol:@protocol(ZDMCommonProtocol) selAndArgs:@selector(zdm_handleEvent:userInfo:callback:), 100, @{}, ^id(NSString *name){
            if (name) {
                [results1 addObject:name];
            }
            return nil;
        }];
        NSLog(@"---> %@", results1);
        
        NSArray *results2 = [ZDMOneForAll dispatchWithProtocol:@protocol(AnimalProtocol) selAndArgs:@selector(eatFood), nil];
        NSLog(@"---> %@", results2);
    }
    
    NSArray *names = [ZDMOneForAll dispatchWithProtocol:@protocol(AnimalProtocol) selAndArgs:@selector(animalName), nil];
    XCTAssertGreaterThanOrEqual(names.count, 2);
    
    NSLog(@"++++++++++++");
}

- (void)testPerformance1 {
    __auto_type dog = [ZDDog new];
    
    [self measureBlock:^{
        NSInteger age = [dog age];
        NSLog(@"age = %ld", (long)age);
    }];
}

- (void)testPerformance2 {
    __auto_type dog = [ZDDog new];
    [ZDMOneForAll manualRegisterService:@protocol(DogProtocol) priority:200 implementer:dog weakStore:NO];
    
    [self measureBlock:^{
        ZDDog *dog = GetServiceWithPriority(DogProtocol, 200);
        NSInteger age = [dog age];
        NSLog(@"age = %ld", (long)age);
    }];
}

@end
