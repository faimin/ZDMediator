//
//  ZDDispatchTest.m
//  ZDMediator_Tests
//
//  Created by Zero_D_Saber on 2025/8/5.
//  Copyright © 2025 8207436. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ZDMediator;
#import "AnimalProtocol.h"
#import "DogProtocol.h"

@interface ZDDispatchTest : XCTestCase

@end

@implementation ZDDispatchTest

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

- (void)testDispatchWithEvent {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [ZDMOneForAll registerResponder:@protocol(DogProtocol)
                           priority:ZDMPriorityHigh
                          selectors:@selector(foo:), @selector(bar:), nil];
#pragma clang diagnostic pop
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    __unused NSArray *fooRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 1];
    XCTAssertEqual(fooRes1.count, 0);
    
    __unused NSArray *fooRes2 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(foo:), 2];
    XCTAssertEqual(fooRes2.count, 0);
    
    NSArray *barRes1 = [ZDMOneForAll dispatchWithEventSelAndArgs:@selector(bar:), @{@"name" : @"zero.d.saber"}];
    XCTAssertEqualObjects(barRes1.firstObject, @"name");
    
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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
