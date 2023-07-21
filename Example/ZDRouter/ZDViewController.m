//
//  ZDViewController.m
//  ZDRouter
//
//  Created by 8207436 on 04/16/2023.
//  Copyright (c) 2023 8207436. All rights reserved.
//

#import "ZDViewController.h"
#import <ZDRouter/ZDRouter.h>
#import "ZDProtocol.h"

@interface ZDViewController ()

@end

@implementation ZDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    __auto_type value = GetService(ZDProtocol);
    [value hello];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)helloWorld {
    
}

@end
