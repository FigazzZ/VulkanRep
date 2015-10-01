//
//  ViewController.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "ViewController.h"
#import "AVCaptureManager.h"
#import "NetworkSocketHandler.h"
#import "CameraProtocol.h"
#import "CommandWithValue.h"
#import "CameraSettings.h"
#import "CommonUtility.h"
#import "CommonNotificationNames.h"

static NSString *const kMinServerVersion = @"0.3.0.0";

// has selectors "handle<CommandType>Command:"
static const CommandType observedCommands[] = {
        START,
        STOP,
        POSITION,
        GET_POSITION,
        DELETE,
        CAMERA_SETTINGS
};

@interface ViewController ()

@property(nonatomic, strong) AVCaptureManager *captureManager;
@property(nonatomic, strong) StreamServer *streamServer;

@end


@implementation ViewController {
    NetworkSocketHandler *socketHandler;
    NSNumber *delay;
    CameraState mode;
    NSURL *file;
    BOOL logoIsWhite;
    NSTimer *dimTimer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    mode = AIM_MODE;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [UIScreen mainScreen].brightness = 1;
    [self drawGrid];
    self.streamServer = [[StreamServer alloc] init];
    [self.streamServer startAcceptingConnections];
    [self setupCamera];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    socketHandler = [[NetworkSocketHandler alloc] init:1111 protocol:[[CameraProtocol alloc] init] minServerVer:kMinServerVersion];
    [self registerToNotifications];
    [self hideStatusBar];

    [self setUpWifiAnimation];
    [_wifiImage startAnimating];
}

- (void)setupCamera {
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
    [self setCameraFramerate];
    self.captureManager.streamServer = self.streamServer;
}

- (void)drawGrid {
    CGRect frame = self.view.frame;
    if (frame.size.width < frame.size.height) {
        CGPoint origin = self.view.frame.origin;
        frame = CGRectMake(origin.x, origin.y, frame.size.height, frame.size.width);
    }
    frame.size.width -= _controls.frame.size.width - 1;
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    float yDiv = height / 4.0F;
    float xDiv = width / 4.0F;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [self drawLineOnPath:path start:CGPointMake(0, yDiv) end:CGPointMake(width, yDiv)];
    [self drawLineOnPath:path start:CGPointMake(0, yDiv * 2) end:CGPointMake(width, yDiv * 2)];
    [self drawLineOnPath:path start:CGPointMake(0, yDiv * 3) end:CGPointMake(width, yDiv * 3)];
    [self drawLineOnPath:path start:CGPointMake(xDiv, 0) end:CGPointMake(xDiv, height)];
    [self drawLineOnPath:path start:CGPointMake(xDiv * 2, 0) end:CGPointMake(xDiv * 2, height)];
    [self drawLineOnPath:path start:CGPointMake(xDiv * 3, 0) end:CGPointMake(xDiv * 3, height)];

    CAShapeLayer *blackLayer = [self drawPathOnLayer:path withColor:[UIColor blackColor] andLineWidth:1.5];
    CAShapeLayer *whiteLayer = [self drawPathOnLayer:path withColor:[UIColor whiteColor] andLineWidth:2.0];
    [_gridView.layer addSublayer:whiteLayer];
    [_gridView.layer addSublayer:blackLayer];
}

- (void)drawLineOnPath:(UIBezierPath *)path start:(CGPoint)start end:(CGPoint)end {
    [path moveToPoint:start];
    [path addLineToPoint:end];
}

- (CAShapeLayer *)drawPathOnLayer:(UIBezierPath *)path withColor:(UIColor *)color andLineWidth:(CGFloat)width {
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.strokeColor = color.CGColor;
    layer.lineWidth = width;
    layer.fillColor = [UIColor clearColor].CGColor;
    return layer;
}

- (void)setUpWifiAnimation {
    NSArray *imageNames = @[@"wifi_1.png", @"wifi_2.png", @"wifi_3.png", @"wifi_4.png"];
    NSMutableArray *images = [[NSMutableArray alloc] init];
    for (int i = 0; i < imageNames.count; i++) {
        [images addObject:[UIImage imageNamed:imageNames[i]]];
    }
    _wifiImage.animationImages = images;
    _wifiImage.animationDuration = 1;
}

- (void)registerToNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    size_t length = sizeof(observedCommands) / sizeof(CommandType);
    for (int i = 0; i < length; i++) {
        [Command addNotificationObserverForCommandType:self commandType:observedCommands[i]];
    }
    [center addObserver:self selector:@selector(connectedToServer) name:kNNConnected object:socketHandler];
    [center addObserver:self selector:@selector(disconnectedFromServer) name:kNNDisconnected object:socketHandler];
    [center addObserver:self selector:@selector(wentToBackground) name:kNNCloseAll object:nil];
    [center addObserver:self selector:@selector(cameToForeground) name:kNNRestoreAll object:nil];
    [center addObserver:self selector:@selector(receiveStreamNotification:) name:kNNStream object:nil];

    [center addObserver:self
               selector:@selector(sendJsonAndVideo:)
                   name:@"StopNotification"
                 object:nil];
}

- (void)receiveStreamNotification:(NSNotification *)notification {
    NSDictionary *cmdDict = notification.userInfo;
    NSString *msg = cmdDict[@"message"];
    if ([msg isEqualToString:@"start"]) {
        if (mode == CAMERA_MODE) {
            [self stopLogoAnimation];
        }
    }
    else if ([msg isEqualToString:@"stop"]) {
        if (mode == CAMERA_MODE) {
            [self startLogoAnimation];
        }
    }
}

- (void)connectedToServer {
    [_wifiImage stopAnimating];
    _wifiImage.image = [UIImage imageNamed:@"wifi_connected"];
    NSString *ID = [[NSUserDefaults standardUserDefaults] stringForKey:@"uuid"];
    [[NSUserDefaults standardUserDefaults] setValue:ID forKey:@"uuid"];

    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:UUID :ID]];
}

- (void)disconnectedFromServer {
    [_wifiImage startAnimating];
}

- (void)wentToBackground {
    // TODO: close socket, stream stuff, camera?
//    [socketHandler sendCommand:[[Command alloc] init:QUIT]];
    [self.streamServer stopAcceptingConnections];
    [_captureManager closeAssetWriter];
}

- (void)cameToForeground {
    if (mode == CAMERA_MODE) {
        dimTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dimScreen) userInfo:nil repeats:NO];
    }
    else {
        [UIScreen mainScreen].brightness = 1;
    }
    // TODO: restore what was closed when went to background
    [self.streamServer startAcceptingConnections];
    [_captureManager prepareAssetWriter];
}

- (void)dimScreen {
    [UIScreen mainScreen].brightness = 0;
}

- (void)hideStatusBar {
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // iOS 7
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    }
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)setCameraFramerate {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        if ([self.captureManager switchFormatWithDesiredFPS:120.0]) {
            // TODO: something
        }
        else if ([self.captureManager switchFormatWithDesiredFPS:60.0]) {
            // TODO: something
        }
        else {
            [self.captureManager resetFormat];
        }
    });

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)handleStartCommand:(NSNotification *)notification {
    if (mode == CAMERA_MODE && !_captureManager.isRecording) {
        NSLog(@"Started recording");
        NSTimeInterval startTime = [NSDate date].timeIntervalSince1970;
        [_captureManager startRecording];
        delay = @([NSDate date].timeIntervalSince1970 - startTime);
        [socketHandler sendCommand:[[Command alloc] init:OK]];
    }
    else {
        NSLog(@"was already recording");
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)handleStopCommand:(NSNotification *)notification {
    if (_captureManager.isRecording) {
        [_captureManager stopRecording];
    }
    else {
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)sendJsonAndVideo:(NSNotification *)notification {
    NSDictionary *dict = notification.userInfo;
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    CameraSettings *sharedVars = [CameraSettings sharedVariables];
    NSDictionary *pov = sharedVars.positionJson;
    NSNumber *fps = @(sharedVars.framerate);
    json[@"fps"] = fps;
    json[@"pointOfView"] = pov;
    json[@"delay"] = delay;
    file = dict[@"file"];
    AVURLAsset *sourceAsset = [AVURLAsset URLAssetWithURL:file options:nil];
    CMTime duration = sourceAsset.duration;
    NSNumber *dur = @(CMTimeGetSeconds(duration));
    json[@"duration"] = dur;
    NSString *jsonStr = [CommonUtility convertNSDictToJSONString:json];
    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:VIDEO_COMING :jsonStr]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *path = file.path;
        NSData *bytes = [[NSData alloc] initWithContentsOfFile:path];
        NSLog(@"Sending video");
        [socketHandler sendCommand:[[CommandWithValue alloc] init:VIDEODATA :bytes]];
    });
}

- (void)handlePositionCommand:(NSNotification *)notification {
    Command *command = [Command getCommandFromNotification:notification];
    assert(command != nil);
    if ([command isKindOfClass:[CommandWithValue class]]) {
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
        NSString *JSONString = [[NSString alloc] initWithData:command.data encoding:NSUTF8StringEncoding];
        NSDictionary *json = [CommonUtility getNSDictFromJSONString:JSONString];
        sharedVars.dist = [json[@"dist"] doubleValue];
        sharedVars.yaw = [json[@"yaw"] intValue];
        sharedVars.pitch = [json[@"pitch"] intValue];
    }
}

- (void)handleGetPositionCommand:(NSNotification *)notification {
    CameraSettings *sharedVars = [CameraSettings sharedVariables];
    NSDictionary *pov = @{@"dist" : @(sharedVars.dist),
            @"yaw" : @(sharedVars.yaw),
            @"pitch" : @(sharedVars.pitch)};
    NSString *jsonStr = [CommonUtility convertNSDictToJSONString:pov];
    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:POSITION :jsonStr]];
}

- (void)handleCameraSettingsCommand:(NSNotification *)notification {
    Command *cmd = [Command getCommandFromNotification:notification];
    if ([cmd isKindOfClass:[CommandWithValue class]]) {
        NSString *jsonString = ((CommandWithValue *) cmd).dataAsString;
        NSDictionary *dict = [CommonUtility getNSDictFromJSONString:jsonString][@"touch"];
        CFDictionaryRef pointDict = (__bridge_retained CFDictionaryRef) (dict);
        CGPoint point;
        if (CGPointMakeWithDictionaryRepresentation(pointDict, &point)) {
            [self.captureManager setCameraSettings:point];
        }
        CFRelease(pointDict);
    }
}

- (void)handleDeleteCommand:(NSNotification *)notification {
    [AVCaptureManager deleteVideo:file];
}


// =============================================================================
#pragma mark - Gesture Handler

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.view];
    CGFloat newX = point.x / self.view.frame.size.width;
    CGFloat newY = point.y / self.view.frame.size.height;
    point = CGPointMake(newX, newY);
    [self.captureManager setCameraSettings:point];
}


- (IBAction)switchToAimMode:(id)sender {
    if (mode != AIM_MODE) {
        mode = AIM_MODE;
        [UIScreen mainScreen].brightness = 1;
        [dimTimer invalidate];
        [_captureManager addPreview:self.view];
        _logoView.hidden = YES;
        _gridView.hidden = NO;
        [_aimMode setImage:[UIImage imageNamed:@"aim_mode_selected"] forState:UIControlStateNormal];
        [_cameraMode setImage:[UIImage imageNamed:@"camera_mode_off"] forState:UIControlStateNormal];
        [self stopLogoAnimation];
    }
}

- (IBAction)switchToCameraMode:(id)sender {
    if (mode != CAMERA_MODE && socketHandler.isConnectedToTCP) {
        mode = CAMERA_MODE;
        if (dimTimer == nil || !dimTimer.valid) {
            dimTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dimScreen) userInfo:nil repeats:NO];
        }
        _logoView.hidden = NO;
        [_captureManager removePreview];
        if (!_captureManager.isStreaming) {
            _logo.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
            logoIsWhite = YES;
            [self startLogoAnimation];
        }
        _gridView.hidden = YES;
        [_aimMode setImage:[UIImage imageNamed:@"aim_mode_off"] forState:UIControlStateNormal];
        [_cameraMode setImage:[UIImage imageNamed:@"camera_mode_selected"] forState:UIControlStateNormal];
    }
}

- (void)startLogoAnimation {
    BOOL newLogoState;
    UIColor *color;
    if (logoIsWhite) {
        color = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
        newLogoState = NO;
    }
    else {
        color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        newLogoState = YES;
    }
    [UIView animateWithDuration:4.0 delay:0 options:(UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat)
                     animations:^{
                         _logo.backgroundColor = color;
                     }
                     completion:^(BOOL res) {
                         logoIsWhite = newLogoState;
                     }];
}

- (void)stopLogoAnimation {
    [_logo.layer removeAllAnimations];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIScreen mainScreen].brightness = 1;
    [dimTimer invalidate];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (mode == CAMERA_MODE && (dimTimer == nil || !dimTimer.valid)) {
        dimTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dimScreen) userInfo:nil repeats:NO];
    }
}


@end
