//
//  ViewController.m
//  AsyncDrawDemo
//
//  Created by SZOeasy on 2020/8/10.
//  Copyright © 2020 ycong. All rights reserved.
//

#import "ViewController.h"
#import "AsyncLabel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    AsyncLabel *label = [[AsyncLabel alloc] initWithFrame:CGRectMake(20, 100, 200, 200)];
    label.backgroundColor = [UIColor lightGrayColor];
    label.text = @"测试测试测试测试测试测试测试测试测试测试测试测试测试";
    label.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:label];
//    [label.layer setNeedsDisplay];
}


@end
