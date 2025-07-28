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
    // Put teardown code here. This method is called after the invocation of each
    // test method in the class.
    [super tearDown];
}

- (void)testExample {
    BOOL catResult1 = [ZDMGetService(CatProtocol) zdm_handleEvent:100 userInfo:@{} callback:^id(NSString *x) {
        return @[ x ];
    }];
    XCTAssertTrue(catResult1);
    
    NSString *sex = [ZDMGetService(CatProtocol) sex];
    XCTAssertNotNil(sex);
    
    //----------------------------------
    
    BOOL dogResult1 = [ZDMGetService(DogProtocol) zdm_handleEvent:123 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    BOOL dogResult2 = [ZDMGetService(DogProtocol) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y) {
        XCTAssertEqual(x, 2);
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
    NSArray *dogResult3 = [ZDMGetService(ZDClassProtocol) foo:@[ @1, @2 ] bar:@[ @3, @4, @5 ]];
    XCTAssertEqual(dogResult3.count, 5);
    
    NSString *animalName = [ZDMGetServiceWithPriority(AnimalProtocol, 1) animalName];
    XCTAssertTrue([animalName isEqualToString:@"小狗"]);
}

- (void)testWeakStore {
    {
        __auto_type dog = [ZDDog new];
        [ZDMOneForAll manualRegisterService:@protocol(DogProtocol) priority:100 implementer:dog weakStore:YES];
    }
    
    XCTestExpectation *expect = [self expectationWithDescription:@"弱引用测试"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSObject *dog = ZDMGetServiceWithPriority(DogProtocol, 100);
        NSLog(@"%@", dog);
        XCTAssertNil(dog);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

- (void)testPriority {
    NSString *clsName = NSStringFromClass([ZDMGetServiceWithPriority(AnimalProtocol, 1) class]);
    XCTAssertTrue([clsName isEqualToString:@"ZDDog"]);
    
    BOOL res = [ZDMGetServiceWithPriority(AnimalProtocol, 1) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertTrue(res);
}

// 测试方法不是别的异常处理
- (void)testUnrecognizedMethod {
    NSObject *cat = ZDMGetServiceWithPriority(CatProtocol, 0);
    XCTAssertTrue([NSStringFromClass([cat class]) isEqualToString:@"ZDCat"]);
    
    // 是否crash
    NSString *foodName = [ZDMGetServiceWithPriority(CatProtocol, 0) eatWhatFood];
    XCTAssertNil(foodName);
    
    NSObject *dog = ZDMGetServiceWithClass(CatProtocol, 0, ZDDog);
    XCTAssertNil(dog);
}

// 测试注册时说明全是类方法，但其实并不是的异常情况
- (void)testAllClassMethodException {
    __auto_type dog = ZDMGetService(DogProtocol);
    NSInteger age = [dog age];
    XCTAssertEqual(age, 2);
    
    __auto_type dog2 = ZDMGetService(DogProtocol);
    XCTAssertTrue([dog2 isKindOfClass:NSClassFromString(@"ZDDog")]);
}

- (void)testDispatch {
    ZDMIGNORE_SELWARNING(
                         __unused NSArray *fooRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         __unused NSArray *fooRes2 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         __unused NSArray *barRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(bar:), @{@"name" : @"zero.d.saber"}];
                         
                         [ZDMOneForAll dispatchWithEventId:@"100" selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 200, @{@100 : @"100"}, nil];
                         
                         NSArray *broadcastResult = [ZDMOneForAll dispatchWithSELAndArgs:@selector(application: didFinishLaunchingWithOptions:), UIApplication.sharedApplication, @{@"1111": @"---2222"}];
                         NSLog(@"事件分发结果 = %@", broadcastResult);
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

- (void)testRemoveService {
    id cat = ZDMGetService(CatProtocol);
    XCTAssertNotNil(cat);
    
    [ZDMOneForAll removeService:@protocol(CatProtocol) priority:0 autoInitAgain:NO];
    XCTAssertNil(ZDMGetService(CatProtocol));
    
    NSString *name = [ZDMGetService(CatProtocol) name];
    XCTAssertNil(name);
}

- (void)testBroadcast {
    __auto_type dog = [ZDDog new];
    [ZDMOneForAll manualRegisterService:@protocol(DogProtocol) implementer:dog];
    
    __auto_type proxy = (ZDMBroadcastProxy<ZDMCommonProtocol> *)[[ZDMBroadcastProxy alloc] initWithHashTable:[ZDMOneForAll allInitializedObjects]];
    [proxy zdm_handleEvent:999 userInfo:@{@"a": @"aaaaa"} callback:^id{
        return @(YES);
    }];
}

- (void)testPerformance1 {
    __auto_type dog = [ZDDog new];
    
    [self measureBlock:^{
        NSInteger age = [dog age];
        NSLog(@"age = %ld", (long)age);
    }];
}

- (void)testPerformance2 {
    [self measureBlock:^{
        ZDDog *dog = ZDMGetService(DogProtocol);
        NSInteger age = [dog age];
        NSLog(@"age = %ld", (long)age);
    }];
}

@end
