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
#import "ZDCat.h"
#import "ZDClassProtocol.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each
    // test method in the class.
    
    __auto_type cat = [ZDCat new];
    [ZDM1V1 manualRegisterService:@protocol(CatProtocol) implementer:cat];
    
    [ZDM1V1 registerResponder:@protocol(DogProtocol)
                     priority:ZDMPriorityHigh
                    selectors:@selector(foo:), @selector(bar:), nil];
    
    [ZDM1V1 registerResponder:@protocol(DogProtocol)
                     priority:ZDMPriorityDefalut
                      eventId:@"100", @"200"];
    [ZDM1V1 registerResponder:@protocol(CatProtocol)
                     priority:ZDMPriorityDefalut
                      eventId:@"100", @"200"];
}

- (void)tearDown {
    [ZDM1V1 removeService:@protocol(CatProtocol) autoInitAgain:NO];
    
    NSString *name = [GetService(CatProtocol) name];
    XCTAssertNil(name);
    
    // Put teardown code here. This method is called after the invocation of each
    // test method in the class.
    [super tearDown];
}

- (void)testExample {
    BOOL catResult1 = [GetService(CatProtocol) zdm_handleEvent:100
                                                      userInfo:@{}
                                                      callback:^id(NSString *x) {
        return @[ x ];
    }];
    XCTAssertTrue(catResult1);
    
    NSString *sex = [GetService(CatProtocol) sex];
    XCTAssertNotNil(sex);
    
    //----------------------------------
    
    BOOL dogResult1 = [GetService(DogProtocol) zdm_handleEvent:100
                                                      userInfo:@{}
                                                      callback:^id(NSUInteger x) {
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    BOOL dogResult2 =
    [GetService(DogProtocol) zdm_handleEvent:200
                                    userInfo:@{}
                                    callback:^id(NSUInteger x, NSString *y) {
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        XCTAssertEqual(x, 2);
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
    NSArray *dogResult3 = [GetService(ZDClassProtocol) foo:@[ @1, @2 ] bar:@[ @3, @4, @5 ]];
    XCTAssertEqual(dogResult3.count, 5);
}

- (void)testDispatch {
    ZDMIGNORE_SELWARNING(
                         [ZDM1V1 dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         [ZDM1V1 dispatchWithEventSelAndArgs:@selector(foo:), 1];
                         
                         [ZDM1V1 dispatchWithEventSelAndArgs:@selector(bar:), @{@"name" : @"zero.d.saber"}];
                         )
    
    [ZDM1V1 dispatchWithEventId:@"100" selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 200, @{@100 : @"100"}, nil];
    
    NSMutableArray *results1 = @[].mutableCopy;
    [ZDM1VM dispatchWithProtocol:@protocol(ZDMCommonProtocol)
                      selAndArgs:@selector(zdm_handleEvent:userInfo:callback:), 100, @{}, ^id(NSString *name){
        if (name) {
            [results1 addObject:name];
        }
        return nil;
    }];
    NSLog(@"---> %@", results1);
    
    NSArray *results2 = [ZDM1VM dispatchWithProtocol:@protocol(AnimalProtocol) selAndArgs:@selector(eatFood), nil];
    NSLog(@"---> %@", results2);
    NSLog(@"++++++++++++");
}

@end
