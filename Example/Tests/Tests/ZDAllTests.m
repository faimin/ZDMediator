//
//  ZDAllTests.m
//  ZDAllTests
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
#import "ZDTiger.h"

typedef NS_ENUM(NSInteger, ZDMPriority) {
    ZDMPriorityLow = -100,
    ZDMPriorityDefalut = 0,
    ZDMPriorityHigh = 100,
};

@interface ZDAllTests : XCTestCase

@end

@implementation ZDAllTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [ZDMOneForAll registerResponder:@protocol(DogProtocol)
                           priority:ZDMPriorityHigh
                          selectors:@selector(foo:), @selector(bar:), nil];
#pragma clang diagnostic pop
    
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
    __auto_type cat = [ZDCat new];
    [ZDMOneForAll manualRegisterService:@protocol(CatProtocol) implementer:cat];
    
    BOOL catResult1 = [ZDMGetService(CatProtocol) zdm_handleEvent:100 userInfo:@{} callback:^id(NSString *x) {
        return @[ x ];
    }];
    XCTAssertTrue(catResult1);
    
    NSString *sex = [ZDMGetService(CatProtocol) sex];
    XCTAssertNotNil(sex);
    
    //----------------------------------
    
    id<DogProtocol> dog1 = ZDMGetServiceWithPriority(DogProtocol, ZDMDefaultPriority);
    BOOL dogResult1 = [dog1 zdm_handleEvent:123 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    id<DogProtocol> dog2 = ZDMGetServiceWithPriority(DogProtocol, ZDDog.zdm_priority);
    XCTAssertEqualObjects(dog1, dog2);
    BOOL dogResult2 = [dog2 zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y) {
        XCTAssertEqual(x, 2);
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
    [ZDMOneForAll manualRegisterService:@protocol(ZDClassProtocol) implementer:ZDDog.self];
    id<ZDClassProtocol> instance = ZDMGetService(ZDClassProtocol);
    NSArray *dogResult3 = [instance foo:@[ @1, @2 ] bar:@[ @3, @4, @5 ]];
    XCTAssertEqual(dogResult3.count, 5);
    
    NSString *animalName = [ZDMGetServiceWithPriority(AnimalProtocol, ZDDog.zdm_priority) animalName];
    XCTAssertTrue([animalName isEqualToString:@"小狗"]);
}

- (void)testWeakStore {
    __auto_type proxy = (id<AnimalProtocol>)ZDMOneForAll.shareInstance.proxy;
    {
        __auto_type tiger = [ZDTiger new];
        [ZDMOneForAll manualRegisterService:@protocol(AnimalProtocol) priority:100 implementer:tiger weakStore:YES];
        [proxy eatFood];
        
        id x = (id<AnimalProtocol>)ZDMOneForAll.shareInstance.proxy;
        XCTAssertEqualObjects(proxy, x);
    }
    
    [proxy eatFood];
    
    XCTestExpectation *expect = [self expectationWithDescription:@"弱引用测试"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSObject *tiger = ZDMGetServiceWithPriority(AnimalProtocol, 100);
        XCTAssertNil(tiger);
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

- (void)testPriority {
    NSInteger dogPriority = ZDDog.zdm_priority;
    NSString *clsName = NSStringFromClass([ZDMGetServiceWithPriority(AnimalProtocol, dogPriority) class]);
    XCTAssertTrue([clsName isEqualToString:@"ZDDog"]);
    
    BOOL res = [ZDMGetServiceWithPriority(AnimalProtocol, dogPriority) zdm_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertTrue(res);
}

// 测试方法不识别的异常处理
- (void)test100UnrecognizedMethod {
    NSObject *cat = ZDMGetServiceWithPriority(CatProtocol, ZDMDefaultPriority);
    XCTAssertTrue([cat isKindOfClass:ZDCat.class]);
    
    // 是否crash
    NSString *foodName = [ZDMGetServiceWithPriority(CatProtocol, ZDMDefaultPriority) eatWhatFood];
    XCTAssertNil(foodName);
    
    NSObject *dog = ZDMGetServiceWithClass(CatProtocol, ZDMDefaultPriority, ZDDog);
    XCTAssertNil(dog);
}

// 测试注册时说明全是类方法，但其实并不是的异常情况
- (void)testAllClassMethodException {
    __auto_type dog1 = ZDMGetServiceWithPriority(DogProtocol, ZDMDefaultPriority);
    NSInteger age = [dog1 age];
    XCTAssertEqual(age, 2);
    
    __auto_type dog2 = ZDMGetServiceWithPriority(DogProtocol, 12345);
    XCTAssertTrue([dog2 isKindOfClass:ZDDog.class]);
}

- (void)testDispatchWithEvent {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    __unused NSArray *fooRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
    __unused NSArray *fooRes2 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
    __unused NSArray *barRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(bar:), @{@"name" : @"zero.d.saber"}];
    
    [ZDMOneForAll dispatchWithEventId:@"100" selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 200, @{@100 : @"100"}, nil];
#pragma clang diagnostic pop
}

- (void)testDispatchWithProtocol {
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

- (void)testDispatchWithSEL {
    NSArray *broadcastResult1 = [ZDMOneForAll dispatchWithSELAndArgs:@selector(application: didFinishLaunchingWithOptions:), UIApplication.sharedApplication, @{@"1111": @"---2222"}];
    NSLog(@"事件分发结果1 = %@", broadcastResult1);
    XCTAssertNotNil(broadcastResult1, @"Dispatch result should not be nil");
    
    NSArray *broadcastResult2 = [ZDMOneForAll dispatchWithSELAndArgs:@selector(zdm_handleEvent:userInfo:callback:), 12345, @{@"3333": @"---4444"}, ^id{
        return @"++++++++++";
    }];
    NSLog(@"事件分发结果2 = %@", broadcastResult2);
    XCTAssertNotNil(broadcastResult2, @"Dispatch result should not be nil");
}

/// 确保`test100UnrecognizedMethod`先执行
- (void)test9999RemoveService {
    id cat = ZDMGetService(CatProtocol);
    XCTAssertNotNil(cat);
    
    [ZDMOneForAll removeService:@protocol(CatProtocol) priority:ZDMDefaultPriority autoInitAgain:NO];
    XCTAssertNil(ZDMGetService(CatProtocol));
    
    NSString *name = [ZDMGetService(CatProtocol) name];
    XCTAssertNil(name);
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
