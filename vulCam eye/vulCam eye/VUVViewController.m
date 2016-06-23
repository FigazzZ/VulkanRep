//
//  VUVViewController.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import "VUVViewController.h"
#import "VUVAVCaptureManager.h"
#import "NetworkSocketHandler.h"
#import "VUVCameraProtocol.h"
#import "CommandWithValue.h"
#import "VUVCameraSettings.h"
#import "CommonUtility.h"
#import "CommonNotificationNames.h"
#import "CommonJSONKeys.h"
#import "VUVCamNotificationNames.h"
#import "SplashScreen.h"
#import <ios-ntp/ios-ntp.h>

static NSString *const kMinServerVersion = @"0.4.3.0";

// has selectors "handle<CommandType>Command:"
static const CommandType observedCommands[] = {
        START,
        STOP,
        IMPACT_START,
        IMPACT_STOP,
        POSITION,
        GET_POSITION,
        DELETE,
        CAMERA_SETTINGS,
        SET_FPS,
        SET_SHUTTERSPEED,
};

@interface VUVViewController ()

@property(nonatomic, strong) VUVAVCaptureManager *captureManager;
@property(nonatomic, strong) VUVStreamServer *streamServer;

@end


@implementation VUVViewController {
    NetworkSocketHandler *socketHandler;
    NSNumber *delay;
    CameraState mode;
    NSURL *file;
    BOOL logoIsWhite;
    NSTimer *dimTimer;
    NSTimer *ntpTimer;
    NetAssociation *netAssociation;
    UITapGestureRecognizer *tapGesture;
    NSTimeInterval impactStart;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    mode = AIM_MODE;
    [self drawSplashScreen];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [UIScreen mainScreen].brightness = 1;
    //[self drawGrid];
    _streamServer = [[VUVStreamServer alloc] init];
    [_streamServer startAcceptingConnections];
    [self setupCamera];

    tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        socketHandler = [[NetworkSocketHandler alloc] init:1111
                                                  protocol:[[VUVCameraProtocol alloc] init]
                                              minServerVer:kMinServerVersion];
    });
    [self registerToNotifications];
    [self hideStatusBar];

    [self setUpWifiAnimation];
    [_wifiImage startAnimating];
    [self.view bringSubviewToFront:_aboutViewWrapper];
    
}

- (void)viewDidLayoutSubviews {
    [self drawGrid];
}

- (void)setupCamera {
    _captureManager = [[VUVAVCaptureManager alloc] initWithPreviewView:self.view];
    [self setCameraFramerate];
    _captureManager.streamServer = _streamServer;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)drawSplashScreen {
    SplashScreen *splashView = [[SplashScreen alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    splashView.tag = 11;
    [self.view addSubview:splashView];
    [CommonUtility setFullscreenConstraintsForView:splashView toSuperview:self.view];

    [NSTimer scheduledTimerWithTimeInterval:4
                                     target:self
                                   selector:@selector(removeSplashScreen:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)removeSplashScreen:(NSTimer *)timer {
    for (UIView *subview in (self.view).subviews) {
        if (subview.tag == 11) {
            [subview removeFromSuperview];
        }
    }
}

- (void)drawGrid {
    CGRect frame = self.view.frame;
    if (frame.size.width < frame.size.height) {
        CGPoint origin = self.view.frame.origin;
        frame = CGRectMake(origin.x, origin.y, frame.size.height, frame.size.width);
    }
    frame.size.width -= _controls.frame.size.width - 1;
    NSLog(@"%f", _gridView.frame.size.width);
    NSLog(@"%f", _controls.frame.origin.x);

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
    //_logo.center = _logoView.center;
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
    for (int i = 0; i < imageNames.count; ++i) {
        [images addObject:[UIImage imageNamed:imageNames[i]]];
    }
    _wifiImage.animationImages = images;
    _wifiImage.animationDuration = 1;
}

- (void)registerToNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    size_t length = sizeof(observedCommands) / sizeof(CommandType);
    for (int i = 0; i < length; ++i) {
        [Command addNotificationObserverForCommandType:self commandType:observedCommands[i]];
    }
    [center addObserver:self selector:@selector(connectedToServer) name:kNNConnected object:socketHandler];
    [center addObserver:self selector:@selector(disconnectedFromServer) name:kNNDisconnected object:socketHandler];
    [center addObserver:self selector:@selector(wentToBackground) name:kNNCloseAll object:nil];
    [center addObserver:self selector:@selector(cameToForeground) name:kNNRestoreAll object:nil];
    [center addObserver:self selector:@selector(receiveStreamNotification:) name:kNNStream object:nil];
    [center addObserver:self selector:@selector(sendStopOKCommand) name:kNNStopOK object:nil];
    [center addObserver:self selector:@selector(sendJsonAndVideo:) name:kNNStopRecording object:nil];
    [center addObserver:self selector:@selector(sendFailedRecordingCommand) name:kNNRecordingFailed object:nil];
    [center addObserver:self selector:@selector(sendTooShortImpactVidCommand) name:kNNTooShortImpactVid object:nil];
}

- (void)sendFailedRecordingCommand {
    [socketHandler sendCommand:[[Command alloc] init:RECORDING_FAILED]];
}

- (void)sendTooShortImpactVidCommand {
    [socketHandler sendCommand:[[Command alloc] init:TOO_SHORT_IMPACT]];
}

- (void)receiveStreamNotification:(NSNotification *)notification {
    NSDictionary *cmdDict = notification.userInfo;
    NSString *msg = cmdDict[@"message"];
    if ([msg isEqualToString:@"start"]) {
        if (mode == CAMERA_MODE) {
            [self stopLogoAnimation];
        }
    }
}

- (void)connectedToServer {
    [_wifiImage stopAnimating];
    _wifiImage.image = [UIImage imageNamed:@"wifi_connected"];
    netAssociation = [[NetAssociation alloc] initWithServerName:socketHandler.hostIP];
    netAssociation.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [netAssociation sendTimeQuery];
    });
    ntpTimer = [NSTimer scheduledTimerWithTimeInterval:15
                                                target:netAssociation
                                              selector:@selector(sendTimeQuery)
                                              userInfo:nil
                                               repeats:YES];
    NSString *ID = [[NSUserDefaults standardUserDefaults] stringForKey:@"uuid"];
    [[NSUserDefaults standardUserDefaults] setValue:ID forKey:@"uuid"];

    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:UUID :ID]];
}

- (void)disconnectedFromServer {
    [ntpTimer invalidate];
    ntpTimer = nil;
    netAssociation = nil;
    [_wifiImage startAnimating];
}

- (void)wentToBackground {
    if (ntpTimer != nil) {
        [ntpTimer invalidate];
        netAssociation = nil;
        ntpTimer = nil;
    }
    [_streamServer stopAcceptingConnections];
    [_captureManager closeAssetWriter];
    [_captureManager stopCaptureSession];
}

- (void)cameToForeground {
    if (mode == CAMERA_MODE) {
        dimTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dimScreen) userInfo:nil repeats:NO];
    }
    else {
        [UIScreen mainScreen].brightness = 1;
    }
    [_streamServer startAcceptingConnections];
    [_captureManager startCaptureSession];
    [_captureManager prepareAssetWriter];
}

- (void)dimScreen {
    [UIScreen mainScreen].brightness = 0;
    [self stopLogoAnimation];
}

- (void)hideStatusBar {
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // iOS 7
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    }
}


- (IBAction)hideAboutView:(id)sender {
    _aboutViewWrapper.hidden = YES;
    [_aboutView closeAboutView];
    [self.view addGestureRecognizer:tapGesture];
}

- (IBAction)showAboutView:(id)sender {
    _aboutViewWrapper.hidden = NO;
    [_aboutView showAboutView];
    [self.view removeGestureRecognizer:tapGesture];
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
        VUVCameraSettings *sharedVars = [VUVCameraSettings sharedVariables];
        if ([_captureManager switchFormatWithDesiredFPS:240.0]) {
            sharedVars.maxFramerate = 240;
        }
        else if ([_captureManager switchFormatWithDesiredFPS:120.0]) {
            sharedVars.maxFramerate = 120;
        }
        else if ([_captureManager switchFormatWithDesiredFPS:60.0]) {
            sharedVars.maxFramerate = 60;
        }
        else {
            [_captureManager resetFormat];
            sharedVars.maxFramerate = 30;
        }
    });
}

- (void)handleSetFPSCommand:(NSNotification *)notification {
    Command *cmd = [Command getCommandFromNotification:notification];
    if ([cmd isKindOfClass:[CommandWithValue class]]) {
        CommandWithValue *valueCommand = (CommandWithValue *) cmd;
        NSInteger framerate = valueCommand.dataAsInt;
        [self setFPS:framerate];
    }
}

- (void)setFPS:(NSInteger)framerate {
    VUVCameraSettings *settings = [VUVCameraSettings sharedVariables];
    if (framerate <= settings.maxFramerate && framerate != settings.framerate && !_captureManager.isRecording) {
        [_captureManager switchFormatWithDesiredFPS:framerate];
    }
}

- (void)handleStartCommand:(NSNotification *)notification
{
    if (mode == CAMERA_MODE && !_captureManager.isRecording)
    {
        Command *command = [Command getCommandFromNotification:notification];
        if ([command isKindOfClass:[CommandWithValue class]] && _timeOffsetInSeconds != INFINITY)
        {
            NSString *serverStartTimeMillis = [[NSString alloc] initWithData:command.data encoding:NSUTF8StringEncoding];
            NSTimeInterval serverStartTime = serverStartTimeMillis.doubleValue / 1000.f + _timeOffsetInSeconds;
            NSDate *serverStartDate = [NSDate dateWithTimeIntervalSince1970:serverStartTime];
            
            [socketHandler sendCommand:[[Command alloc] init:OK]];
            [_captureManager startAssetWriter];

            NSDate *now = [NSDate date];
            NSTimeInterval localStartTimeDiff = [serverStartDate timeIntervalSinceDate:now];

            _captureManager.normalStartTimeDiff = localStartTimeDiff;
            [_captureManager startRecording:STANDARD];
            NSLog(@"Start time difference: %fs", localStartTimeDiff);
        }
        else
        {
            NSLog(@"Start time missing");
            [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
        }
    }
    else
    {
        NSLog(@"was already recording");
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)handleStopCommand:(NSNotification *)notification {
    if (_captureManager.isRecording) {
        [_captureManager stopRecording];
        [socketHandler sendCommand:[[Command alloc] init:STOP_OK]];
    }
    else {
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)handleImpactStartCommand:(NSNotification *)notification {
    if (mode == CAMERA_MODE && !_captureManager.isRecording) {
        if (_timeOffsetInSeconds != INFINITY) {
            Command *command = [Command getCommandFromNotification:notification];
            if ([command isKindOfClass:[CommandWithValue class]]) {
                [socketHandler sendCommand:[[Command alloc] init:OK]];
                [_captureManager startRecording:IMPACT];
                impactStart = [NSDate date].timeIntervalSince1970;
                NSString *JSONString = [[NSString alloc] initWithData:command.data encoding:NSUTF8StringEncoding];
                NSDictionary *json = [CommonUtility getNSDictFromJSONString:JSONString];
                [_captureManager setTimeAfter:[json[kVVImpactAfterKey] floatValue]];
                [_captureManager setTimeBefore:[json[kVVImpactBeforeKey] floatValue]];
            } else {
                [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
            }
        } else {
            NSLog(@"Time offset missing");
            [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
        }
    }
    else {
        NSLog(@"was already recording");
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)handleImpactStopCommand:(NSNotification *)notification {
    if (_captureManager.isRecording) {
        Command *command = [Command getCommandFromNotification:notification];
        if ([command isKindOfClass:[CommandWithValue class]] && _timeOffsetInSeconds != INFINITY) {
            NSString *time = [[NSString alloc] initWithData:command.data encoding:NSUTF8StringEncoding];
            NSTimeInterval impactTime = time.doubleValue / 1000.f + _timeOffsetInSeconds;
            NSTimeInterval interval = impactTime + _captureManager.timeAfter + 0.5;
            NSDate *impactDate = [NSDate dateWithTimeIntervalSince1970:interval];
            interval = impactDate.timeIntervalSinceNow;
            int64_t interval_in_nanos = (int64_t) (interval * NSEC_PER_SEC);
            NSLog(@"Stopping after %f seconds", interval);
            [socketHandler sendCommand:[[Command alloc] init:STOP_OK]];
            _captureManager.impactTime = CMTimeMakeWithSeconds(impactTime - impactStart, NSEC_PER_SEC);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, MAX(interval_in_nanos, 0)), dispatch_get_main_queue(), ^{
                [_captureManager stopRecording];
            });
        } else {
            NSLog(@"Impact time missing");
            [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
        }
    }
    else {
        [socketHandler sendCommand:[[Command alloc] init:NOT_OK]];
    }
}

- (void)sendStopOKCommand {
    [socketHandler sendCommand:[[Command alloc] init:STOP_OK]];
}

- (void)sendJsonAndVideo:(NSNotification *)notification {
    NSDictionary *dict = notification.userInfo;
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    VUVCameraSettings *sharedVars = [VUVCameraSettings sharedVariables];
    json[kVVFramerateKey] = @(sharedVars.framerate);
    json[kVVPointOfViewKey] = sharedVars.positionJson;
    json[kVVDelayKey] = delay;
    file = dict[@"file"];
    AVURLAsset *sourceAsset = [AVURLAsset URLAssetWithURL:file options:nil];
    CMTime duration = sourceAsset.duration;
    json[kVVDurationKey] = @(CMTimeGetSeconds(duration));
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
        VUVCameraSettings *sharedVars = [VUVCameraSettings sharedVariables];
        NSString *JSONString = [[NSString alloc] initWithData:command.data encoding:NSUTF8StringEncoding];
        NSDictionary *json = [CommonUtility getNSDictFromJSONString:JSONString];
        sharedVars.dist = [json[kVVDistanceKey] doubleValue];
        sharedVars.yaw = [json[kVVYawKey] intValue];
        sharedVars.pitch = [json[kVVPitchKey] intValue];
        [self switchToCameraMode:nil];
    }
}

- (void)handleSetShutterSpeedCommand:(NSNotification *)notification {
    Command *cmd = [Command getCommandFromNotification:notification];
    if ([cmd isKindOfClass:[CommandWithValue class]]) {
        int sspeed = ((CommandWithValue *) cmd).dataAsInt;
        [self setShutterSpeed:sspeed];
    }
}

- (void)setShutterSpeed:(int)shutterSpeed {
    VUVCameraSettings *sharedVars = [VUVCameraSettings sharedVariables];
    if (shutterSpeed != sharedVars.shutterSpeed && !_captureManager.isRecording) {
        sharedVars.shutterSpeed = shutterSpeed;
        [_captureManager setShutterSpeed];
    }
}

- (void)handleGetPositionCommand:(NSNotification *)notification {
    VUVCameraSettings *sharedVars = [VUVCameraSettings sharedVariables];
    NSDictionary *pov = @{kVVDistanceKey : @(sharedVars.dist),
            kVVYawKey : @(sharedVars.yaw),
            kVVPitchKey : @(sharedVars.pitch),
            kVVMaxFramerateKey : @(sharedVars.maxFramerate),
            kVVFramerateKey : @(sharedVars.framerate),
            kVVShutterSpeedKey : @(sharedVars.shutterSpeed)};
    NSString *jsonStr = [CommonUtility convertNSDictToJSONString:pov];
    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:POSITION :jsonStr]];
}

- (void)handleCameraSettingsCommand:(NSNotification *)notification {
    Command *cmd = [Command getCommandFromNotification:notification];
    if ([cmd isKindOfClass:[CommandWithValue class]]) {
        NSString *jsonString = ((CommandWithValue *) cmd).dataAsString;
        NSDictionary *dict = [CommonUtility getNSDictFromJSONString:jsonString][@"touch"];
        CFDictionaryRef pointDict = (__bridge_retained CFDictionaryRef) (dict);
        if (pointDict != nil) {
            CGPoint point;
            if (CGPointMakeWithDictionaryRepresentation(pointDict, &point)) {
                [_captureManager setCameraSettings:point];
            }

            CFRelease(pointDict);
        }
    }
}

- (void)handleDeleteCommand:(NSNotification *)notification {
    [VUVAVCaptureManager deleteVideo:file];
}

// =============================================================================
#pragma mark - Gesture Handler

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.view];
    CGFloat newX = point.x / self.view.frame.size.width;
    CGFloat newY = point.y / self.view.frame.size.height;
    point = CGPointMake(newX, newY);
    [_captureManager setCameraSettings:point];
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
            [self startLogoAnimation];
        }
        _gridView.hidden = YES;
        [_aimMode setImage:[UIImage imageNamed:@"aim_mode_off"] forState:UIControlStateNormal];
        [_cameraMode setImage:[UIImage imageNamed:@"camera_mode_selected"] forState:UIControlStateNormal];
    }
}

- (void)startLogoAnimation {
    _logo.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    logoIsWhite = YES;
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
    if (mode == CAMERA_MODE && !_captureManager.isStreaming) {
        [self startLogoAnimation];
    }
    [UIScreen mainScreen].brightness = 1;
    [dimTimer invalidate];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (mode == CAMERA_MODE && (dimTimer == nil || !dimTimer.valid)) {
        dimTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(dimScreen) userInfo:nil repeats:NO];
    }
}

#pragma mark delegates

- (void)reportFromDelegate {
    // Don't sync while recording
    if([_captureManager isRecording]) {
        return;
    }
    
    static const int timeQueryIntervalInSeconds = 10 * 60;
    
    _timeOffsetInSeconds = netAssociation.offset;
    if (_timeOffsetInSeconds != INFINITY && ntpTimer != nil && ntpTimer.timeInterval != timeQueryIntervalInSeconds) {
        [ntpTimer invalidate];
        ntpTimer = [NSTimer scheduledTimerWithTimeInterval:timeQueryIntervalInSeconds
                                                    target:netAssociation
                                                  selector:@selector(sendTimeQuery)
                                                  userInfo:nil
                                                   repeats:YES];
    }
}


@end
