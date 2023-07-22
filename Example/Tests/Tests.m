//
//  ZDRouterTests.m
//  ZDRouterTests
//
//  Created by 8207436 on 04/16/2023.
//  Copyright (c) 2023 8207436. All rights reserved.
//

@import XCTest;
@import ZDRouter;
#import "DogProtocol.h"
#import "CatProtocol.h"
#import "ZDCat.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    __auto_type cat = [ZDCat new];
    
    [ZDRouter.shareInstance manualRegisterService:@protocol(CatProtocol) implementInstance:cat];
}

- (void)tearDown
{
    [ZDRouter.shareInstance removeService:@protocol(CatProtocol) autoInitAgain:NO];
    
    NSString *name = [GetService(CatProtocol) name];
    XCTAssertNil(name);
    
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    //XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
    
    BOOL catResult1 = [GetService(CatProtocol) handleEvent:100 userInfo:@{} callback:^id(NSString * x){
        return @[x];
    }];
    XCTAssertTrue(catResult1);
    
    BOOL dogResult1 = [GetService(DogProtocol) handleEvent:100 userInfo:@{} callback:^id(NSUInteger x){
        return @(x);
    }];
    XCTAssertFalse(dogResult1);
    
    BOOL dogResult2 = [GetService(DogProtocol) handleEvent:200 userInfo:@{} callback:^id(NSUInteger x, NSString *y){
        NSString *a = [NSString stringWithFormat:@"%zd, %@", x, y];
        XCTAssertEqual(x, 2);
        return a;
    }];
    XCTAssertTrue(dogResult2);
    
}

@end

