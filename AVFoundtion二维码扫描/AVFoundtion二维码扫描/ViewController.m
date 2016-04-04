//
//  ViewController.m
//  AVFoundtion二维码扫描
//
//  Created by 汪涛 on 16/4/4.
//  Copyright © 2016年 汪涛. All rights reserved.
//

#import "ViewController.h"
#import "QRCodeScanViewController.h"

#define WIDTH [UIScreen mainScreen].bounds.size.width

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor=[UIColor whiteColor];
    self.title = @"原生二维码扫描";
    
    UIButton *scan_btn = [[UIButton alloc] initWithFrame:CGRectMake(30, 200, WIDTH - 60, 64)];
    [scan_btn setTitle:@"Scan" forState:UIControlStateNormal];
    [scan_btn setTitleColor:[UIColor purpleColor] forState:UIControlStateNormal];
    scan_btn.backgroundColor = [UIColor groupTableViewBackgroundColor];
    scan_btn.layer.borderColor = [UIColor groupTableViewBackgroundColor].CGColor;
    scan_btn.layer.borderWidth = 1.0;
    scan_btn.layer.cornerRadius = 8.0;
    [scan_btn addTarget:self action:@selector(scanAction) forControlEvents:(UIControlEventTouchUpInside)];
    
    [self.view addSubview:scan_btn];
}


- (void)scanAction
{
    QRCodeScanViewController *QRCodeScanVC = [[QRCodeScanViewController alloc] init];
    QRCodeScanVC.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self presentViewController:QRCodeScanVC animated:YES completion:^{
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
