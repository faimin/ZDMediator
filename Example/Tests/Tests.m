//
//  ZDSingleRouterTests.m
//  ZDSingleRouterTests
//
//  Created by 8207436 on 04/16/2023.
//  Copyright (c) 2023 8207436. All rights reserved.
//

@import XCTest;
@import ZDRouter;
#import "DogProtocol.h"
#import "CatProtocol.h"
#import "ZDClassProtocol.h"
#import "ZDCat.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    __auto_type cat = [ZDCat new];
    
    [ZDSingleRouter manualRegisterService:@protocol(CatProtocol) implementer:cat];
    
    [ZDSingleRouter registerResponder:@protocol(DogProtocol) priority:ZDRPriorityHigh selectors:@selector(foo:), @selector(bar:), nil];
    
    [ZDSingleRouter registerResponder:@protocol(DogProtocol) priority:ZDRPriorityDefalut eventId:@"100", @"200"];
    [ZDSingleRouter registerResponder:@protocol(CatProtocol) priority:ZDRPriorityDefalut eventId:@"100", @"200"];
}

- (void)tearDown
{
    [ZDSingleRouter removeService:@protocol(CatProtocol) autoInitAgain:NO];
    
    NSString *name = [GetService(CatProtocol) name];
    XCTAssertNil(name);
    
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    //XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
    
    BOOL catResult1 = [GetService(CatProtocol) zdr_handleEvent:100 userInfo:@{} callback:^id(NSString * x){
        return @[x];
    }];
    XCTAssertTrue(catResult1);
    
    BOOL dogResult1 = [GetService(DogProtocol) zdr_handleEvent:100 userInfo:@{} callback:^id(NSUInteger x){
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    BOOL dogResult2 = [GetService(DogProtocol) zdr_handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y){
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        XCTAssertEqual(x, 2);
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
    NSArray *dogResult3 = [GetService(ZDClassProtocol) foo:@[@1,@2] bar:@[@3,@4,@5]];
    XCTAssertEqual(dogResult3.count, 5);
}

- (void)testDispatch {
//    ZDRIGNORE_SELWARNING(
//        [ZDSingleRouter dispatchWithEventSelAndArgs:@selector(foo:), 1];
//        [ZDSingleRouter dispatchWithEventSelAndArgs:@selector(foo:), 1];
//        
//        [ZDSingleRouter dispatchWithEventSelAndArgs:@selector(bar:), @{
//            @"name": @"zero.d.saber"
//        }];
//    )
//    
//    [ZDSingleRouter dispatchWithEventId:@"100" selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 200, @{@100: @"100"}, nil];
    
    [ZDBroadcastRouter dispatchWithProtocol:@protocol(ZDRCommonProtocol) selAndArgs:@selector(zdr_handleEvent:userInfo:callback:), 101, @{}, nil];
}

@end

