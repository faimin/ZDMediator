//
//  ZDViewController.m
//  ZDRouter
//
//  Created by 8207436 on 04/16/2023.
//  Copyright (c) 2023 8207436. All rights reserved.
//

#import "ZDViewController.h"
#import <ZDRouter/ZDRouter.h>

ZDRouterMachORegister(ZDVCProtocol, ZDViewController)

@interface ZDViewController () <ZDVCProtocol>

@end

@implementation ZDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [ZDRouter shareInstance];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)helloWorld {
    
}

@end
