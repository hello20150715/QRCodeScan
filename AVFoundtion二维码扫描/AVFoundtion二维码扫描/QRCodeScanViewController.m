//
//  ViewController.m
//  二维码扫描
//
//  Created by 汪涛 on 16/3/23.
//  Copyright © 2016年 汪涛. All rights reserved.
//

#import "QRCodeScanViewController.h"
#import <AVFoundation/AVFoundation.h>

#define WIDTH [UIScreen mainScreen].bounds.size.width
#define MARGIN 40       //扫描框距左右距离
#define scanViewY 130   //扫描框距顶部的距离

static const char *kScanQRCodeQueueName = "ScanQRCodeQueue";

@interface QRCodeScanViewController ()<AVCaptureMetadataOutputObjectsDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate>

@property(strong,nonatomic)AVCaptureSession *captureSession;

@property(strong,nonatomic)AVCaptureVideoPreviewLayer *videoPreviewLayer;

//保存用于描边的图层
//@property(strong,nonatomic)CALayer *containerLayer;

//中间有效扫描区域
@property(strong,nonatomic)UIView *scanView;

//扫描区域图片
@property(strong,nonatomic)UIImageView *scanImageView;

//半透明遮盖
@property(strong,nonatomic)UIView *maskView;
@end

@implementation QRCodeScanViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"二维码";
    //初始化扫描区域
    [self setupScanView];
    
    //开始扫描
    [self startScan];
    
    //初始化底部按钮
    [self setupButtons];

    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self resumeAnimation];
}
- (void)setupScanView
{
    CGFloat scanViewWH = WIDTH - MARGIN * 2;
    self.scanView = [[UIView alloc] initWithFrame:CGRectMake(MARGIN, scanViewY, scanViewWH, scanViewWH)];
    self.scanView.clipsToBounds = YES;
    
    self.scanImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_net"]];
    self.scanImageView.contentMode = UIViewContentModeScaleToFill;
    CGFloat buttonWH = 18;
    
    UIButton *topLeft = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, buttonWH, buttonWH)];
    [topLeft setImage:[UIImage imageNamed:@"scan_1"] forState:UIControlStateNormal];
    [_scanView addSubview:topLeft];
    
    UIButton *topRight = [[UIButton alloc] initWithFrame:CGRectMake(scanViewWH - buttonWH, 0, buttonWH, buttonWH)];
    [topRight setImage:[UIImage imageNamed:@"scan_2"] forState:UIControlStateNormal];
    [_scanView addSubview:topRight];
    
    UIButton *bottomLeft = [[UIButton alloc] initWithFrame:CGRectMake(0, scanViewWH - buttonWH, buttonWH, buttonWH)];
    [bottomLeft setImage:[UIImage imageNamed:@"scan_3"] forState:UIControlStateNormal];
    [_scanView addSubview:bottomLeft];
    
    UIButton *bottomRight = [[UIButton alloc] initWithFrame:CGRectMake(scanViewWH - buttonWH, scanViewWH - buttonWH, buttonWH, buttonWH)];
    [bottomRight setImage:[UIImage imageNamed:@"scan_4"] forState:UIControlStateNormal];
    [_scanView addSubview:bottomRight];
    
    UILabel *notice_label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.scanView.frame) + 15, WIDTH, 20)];
    notice_label.textColor = [UIColor whiteColor];
    notice_label.textAlignment = NSTextAlignmentCenter;
    notice_label.font = [UIFont systemFontOfSize:14];
    notice_label.text = @"将取景框对准二维码，即可自动扫描";
    
    [self.view addSubview:_scanView];
    [self.view addSubview:notice_label];
}
- (void)setupButtons
{
    
    CGFloat margin = 100;
    CGFloat btn_width = (WIDTH - 3*margin)/2;
    UIButton *album_btn = [[UIButton alloc] initWithFrame:CGRectMake(margin, self.view.bounds.size.height - 100, btn_width, 44)];
    [album_btn setImage:[UIImage imageNamed:@"qrcode_scan_btn_photo_nor"] forState:UIControlStateNormal];
    [album_btn setImage:[UIImage imageNamed:@"qrcode_scan_btn_photo_down"] forState:UIControlStateSelected];
    [album_btn addTarget:self action:@selector(openAlbum:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *lighting_btn = [[UIButton alloc] initWithFrame:CGRectMake(margin*2 + btn_width, self.view.bounds.size.height - 100, btn_width, 44)];
    [lighting_btn setImage:[UIImage imageNamed:@"qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
    [lighting_btn setImage:[UIImage imageNamed:@"qrcode_scan_btn_flash_down"] forState:UIControlStateSelected];
    [lighting_btn addTarget:self action:@selector(openHight:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:album_btn];
    [self.view addSubview:lighting_btn];

}

//开始扫描
- (BOOL)startScan
{
    //添加半透明遮盖
    [self addMaskView];
    
    [self resumeAnimation];
    
    //获取AVCapureDevice实例
    NSError *error;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    //初始化输入流
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input) {
        NSLog(@"%@",[error localizedDescription]);
        return NO;
    }
    
    //创建会话
    _captureSession = [[AVCaptureSession alloc] init];
    //高质量采集率
    [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    //添加输入输出流
    [_captureSession addInput:input];
    AVCaptureMetadataOutput *captureMetadateOutput = [[AVCaptureMetadataOutput alloc] init];
    
    // 设置有效扫描区域
    CGRect scanCrop=[self getScanCrop:self.scanView.bounds readerViewBounds:self.view.frame];
    NSLog(@"%@",NSStringFromCGRect(scanCrop));
    captureMetadateOutput.rectOfInterest = scanCrop;
    [_captureSession addOutput:captureMetadateOutput];
    
    //创建dispatch queue
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create(kScanQRCodeQueueName, nil);
    [captureMetadateOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    
    //设置元数据类型
    [captureMetadateOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    //预览图层
    _videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession: _captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _videoPreviewLayer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:_videoPreviewLayer atIndex:0];
    
    //开始回话
    [_captureSession startRunning];
    
    return YES;
}

#pragma mark 恢复动画
- (void)resumeAnimation
{
    CAAnimation *anim = [self.scanImageView.layer animationForKey:@"translationAnimation"];
    if(anim){
        // 1. 将动画的时间偏移量作为暂停时的时间点
        CFTimeInterval pauseTime = self.scanImageView.layer.timeOffset;
        // 2. 根据媒体时间计算出准确的启动动画时间，对之前暂停动画的时间进行修正
        CFTimeInterval beginTime = CACurrentMediaTime() - pauseTime;
        
        // 3. 要把偏移时间清零
        [self.scanImageView.layer setTimeOffset:0.0];
        // 4. 设置图层的开始动画时间
        [self.scanImageView.layer setBeginTime:beginTime];
        
        [self.scanImageView.layer setSpeed:1.0];
        
    }else{
        
        CGFloat scanWindowH = WIDTH - MARGIN*2;
        CGFloat scanNetImageViewW = WIDTH - MARGIN*2;
        //这个地方写241  是因为原图尺寸高度是241
        self.scanImageView.frame = CGRectMake(0, -241, scanNetImageViewW, 241);
        CABasicAnimation *scanNetAnimation = [CABasicAnimation animation];
        scanNetAnimation.keyPath = @"transform.translation.y";
        scanNetAnimation.byValue = @(scanWindowH);
        scanNetAnimation.duration = 1.0;
        scanNetAnimation.repeatCount = MAXFLOAT;
        [self.scanImageView.layer addAnimation:scanNetAnimation forKey:@"translationAnimation"];
        [self.scanView addSubview:self.scanImageView];
    }
}

#pragma mark-> 获取扫描区域的比例关系
- (CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds
{
    
    CGFloat x,y,width,height;
    x = (CGRectGetHeight(readerViewBounds)-CGRectGetHeight(rect))/2/CGRectGetHeight(readerViewBounds);
    y = (CGRectGetWidth(readerViewBounds)-CGRectGetWidth(rect))/2/CGRectGetWidth(readerViewBounds);
    width = CGRectGetHeight(rect)/CGRectGetHeight(readerViewBounds);
    height = CGRectGetWidth(rect)/CGRectGetWidth(readerViewBounds);
    
    return CGRectMake(x, y, width, height);
}

//扫描区域外的遮盖
- (void)addMaskView
{
    self.view.clipsToBounds = YES;
    UIView *mask = [[UIView alloc] init];
    mask.bounds = CGRectMake(0, 0, WIDTH + scanViewY + MARGIN + 10, WIDTH + scanViewY + MARGIN +10);
    mask.center = CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.5);
    CGRect frame = mask.frame;
    frame.origin.y = 0;
    mask.frame = frame;
    mask.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6].CGColor;
    mask.layer.borderWidth = scanViewY;
    
    [self.view addSubview:mask];
    
    //上面这段代码生成的遮盖很有意思，，，但是底部会有一部分空白。
    UIView *mask_bottom = [[UIView alloc]initWithFrame:CGRectMake(0, mask.frame.origin.y + mask.bounds.size.height, WIDTH, scanViewY)];
    mask_bottom.backgroundColor=[UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:mask_bottom];

}
//停止扫描
- (void)stopScan
{
    [_captureSession stopRunning];
    _captureSession = nil;
    [self.videoPreviewLayer removeFromSuperlayer];
}
//从相册中选取
- (void)openAlbum:(UIButton *)button
{
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        
        UIImagePickerController *imagePickController = [[UIImagePickerController alloc] init];
        imagePickController.delegate = self;
        imagePickController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        
        
//        UIModalTransitionStyleCoverVertical 从下到上
//        UIModalTransitionStyleFlipHorizontal 翻转
//        UIModalTransitionStyleCrossDissolve  渐变
//        UIModalTransitionStylePartialCurl  翻页下搜过
        //转场动画
        imagePickController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:imagePickController animated:YES completion:nil];
    }
}
//打开闪光灯
- (void)openHight:(UIButton *)button
{
    button.selected = !button.selected;
    if (button.selected) {
        [self turnTorchOn:YES];
    }
    else{
        [self turnTorchOn:NO];
    }
}

#pragma mark-- 开关闪光灯
- (void)turnTorchOn:(BOOL)on
{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}


#pragma mark -- AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects != nil&&[metadataObjects count] > 0) {
        
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        NSString *result;
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            result = metadataObj.stringValue;
        }else{
            NSLog(@"不是二维码");
        }
        
        [self performSelectorOnMainThread:@selector(reportScanResult:) withObject:result waitUntilDone:NO];
    }
}

#pragma mark --UIImagePickerViewControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    //获取选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    //初始化探测器
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    [picker dismissViewControllerAnimated:YES completion:^{
        
    //探测结果
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
        if (features.count>=1) {
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *scanResult = feature.messageString;
            UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"扫描结果" message:scanResult delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alertView show];
            
//            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:scanResult]];

        }else{
            UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"提示" message:@"该图片没有包含一个二维码！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alertView show];
        }
    }];
}
- (void)reportScanResult:(NSString *)result
{
    [self stopScan];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:result]];
    [self.navigationController popViewControllerAnimated:NO];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
