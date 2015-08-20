//
//  ViewController.m
//  VVCamera
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "ViewController.h"
#import "AVCaptureManager.h"
#import "VVNetworkSocketHandler.h"
#import "CameraProtocol.h"
#import "CommandType.h"
#import "Command.h"
#import "CommandWithValue.h"
#import "CameraSettings.h"
#import "StreamServer.h"
#import "VVUtility.h"
#import <QuartzCore/QuartzCore.h>


@interface ViewController ()

@property (nonatomic, strong) AVCaptureManager *captureManager;
@property (nonatomic, strong) StreamServer *streamServer;

@end


@implementation ViewController{
    VVNetworkSocketHandler *socketHandler;
    NSTimeInterval startTime;
    NSString *currentVersionNumber;
    CameraState mode;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    mode = AIM_MODE;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    currentVersionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    // TODO: Close camera and stuff when view disappears
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
    
    [self setCameraFramerate];
    
    [self drawGrid];
    self.streamServer = [[StreamServer alloc] init];
    [self.captureManager setStreamServer:self.streamServer];
    [self.streamServer startAcceptingConnections];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    socketHandler = [[VVNetworkSocketHandler alloc] init:1111 protocol:[[CameraProtocol alloc] init]];
    [self registerToNotifications];
    [self hideStatusBar];
    
    [self setUpWifiAnimation];
    [_wifiImage startAnimating];
}

- (void)drawGrid{
    CGRect frame = self.view.frame;
    if(frame.size.width < frame.size.height){
        CGPoint origin = _gridView.frame.origin;
        frame = CGRectMake(origin.x, origin.y, frame.size.height, frame.size.width);
    }
    frame.size.width = frame.size.width-_controls.frame.size.width;
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    float yDiv = height / 4.0F;
    float xDiv = width / 4.0F;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, yDiv)];
    [path addLineToPoint:CGPointMake(width, yDiv)];
    [path moveToPoint:CGPointMake(0, yDiv*2)];
    [path addLineToPoint:CGPointMake(width, yDiv*2)];
    [path moveToPoint:CGPointMake(0, yDiv*3)];
    [path addLineToPoint:CGPointMake(width, yDiv*3)];
    [path moveToPoint:CGPointMake(xDiv, 0)];
    [path addLineToPoint:CGPointMake(xDiv, height)];
    [path moveToPoint:CGPointMake(xDiv*2, 0)];
    [path addLineToPoint:CGPointMake(xDiv*2, height)];
    [path moveToPoint:CGPointMake(xDiv*3, 0)];
    [path addLineToPoint:CGPointMake(xDiv*3, height)];
    
    CAShapeLayer *blackLayer = [CAShapeLayer layer];
    blackLayer.path = [path CGPath];
    blackLayer.strokeColor = [[UIColor blackColor] CGColor];
    blackLayer.lineWidth = 1.5;
    blackLayer.fillColor = [[UIColor clearColor] CGColor];
    CAShapeLayer *whiteLayer = [CAShapeLayer layer];
    whiteLayer.path = [path CGPath];
    whiteLayer.strokeColor = [[UIColor whiteColor] CGColor];
    whiteLayer.lineWidth = 2.0;
    whiteLayer.fillColor = [[UIColor clearColor] CGColor];
    [_gridView.layer addSublayer:whiteLayer];
    [_gridView.layer addSublayer:blackLayer];
}

- (void)setUpWifiAnimation{
    NSArray *imageNames = @[@"wifi_1.png", @"wifi_2.png", @"wifi_3.png", @"wifi_4.png"];
    NSMutableArray *images = [[NSMutableArray alloc] init];
    for (int i = 0; i < imageNames.count; i++) {
        [images addObject:[UIImage imageNamed:[imageNames objectAtIndex:i]]];
    }
    _wifiImage.animationImages = images;
    _wifiImage.animationDuration = 1;
}

- (void)registerToNotifications{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(receiveProtocolNotification:)
                   name:@"ProtocolNotification"
                 object:nil];
    [center addObserver:self
               selector:@selector(sendJsonAndVideo)
                   name:@"StopNotification"
                 object:nil];
    [center addObserver:self
               selector:@selector(connectedNotification:)
                   name:@"NetworkingNotification"
                 object:nil];
    [center addObserver:self
               selector:@selector(wentToBackground)
                   name:@"Background"
                 object:nil];
    [center addObserver:self
               selector:@selector(cameToForeground)
                   name:@"Foreground"
                 object:nil];
}

- (void)connectedNotification:(NSNotification *) notification{
    NSDictionary *dict = [notification userInfo];
    BOOL connected = [[dict objectForKey:@"isConnected"] boolValue];
    if (connected) {
        [_wifiImage stopAnimating];
        [_wifiImage setImage:[UIImage imageNamed:@"wifi_connected"]];
    }
    else{
        [_wifiImage startAnimating];
    }
}

- (void)wentToBackground{
    // TODO: close socket, stream stuff, camera?
    [socketHandler sendCommand:[[Command alloc] init:QUIT]];
    [self.streamServer stopAcceptingConnections];
}

- (void)cameToForeground{
    // TODO: restore what was closed when went to background
    [self.streamServer startAcceptingConnections];
}

- (void)hideStatusBar
{
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // iOS 7
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    } else {
        // iOS 6
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    }
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)setCameraFramerate{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        if ([self.captureManager switchFormatWithDesiredFPS:120.0]) {
            // TODO: something
        }
        else if ([self.captureManager switchFormatWithDesiredFPS:60.0]){
            // TODO: something
        }
        else {
            [self.captureManager resetFormat];
        }
    });

}

- (void)receiveProtocolNotification:(NSNotification *) notification{
    NSDictionary *cmdDict = [notification userInfo];
    Command *command = [cmdDict objectForKey:@"command"];
    CommandType cType = [command getCommandType];
    
    switch (cType) {
        case START:
            [self startRecording];
            break;
        case STOP:
            [self stopRecording];
            break;
        case POSITION:
            [self setPosition:command];
            break;
        case GET_POSITION:
            [self getPosition];
            break;
        case VERSION:
            // TODO: check version
            break;
        case WRONG_VERSION:
            // TODO: handle wrong version
            break;
        case CAMERA_SETTINGS:
            // Camera settings stuff
            break;
        case PONG:
            // TODO: pong stuff
            break;
        case DELETE:
            [self deleteVideo];
            break;
        case SLEEP:
            // sleep if possible
            break;
        case WAKE:
            break;
        default:
            break;
    }
}

- (void)deleteVideo{
    NSLog(@"Deleting video");
    NSURL *movieURL = [_captureManager getVideoFile];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    
    NSString *path = [movieURL path];
    [manager removeItemAtPath:path error:&error];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)startRecording{
    if(!_captureManager.isRecording){
        startTime = [[NSDate date] timeIntervalSince1970];
        [_captureManager startRecording];
        [socketHandler sendCommand:[[Command alloc] init:OK]];
    }
}

- (void)stopRecording{
    if(_captureManager.isRecording){
        [_captureManager stopRecording];
    }
}

- (void)sendJsonAndVideo{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSNumber *delay = [NSNumber numberWithDouble:now-startTime];
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    CameraSettings *sharedVars = [CameraSettings sharedVariables];
    NSDictionary *pov = [sharedVars getPositionJson];
    NSNumber *fps = [NSNumber numberWithFloat:[sharedVars framerate]];
    [json setObject:fps forKey:@"fps"];
    [json setObject:pov forKey:@"pointOfView"];
    [json setObject:delay forKey:@"delay"];
    NSURL *movieURL = [_captureManager getVideoFile];
    AVURLAsset *sourceAsset = [AVURLAsset URLAssetWithURL:movieURL options:nil];
    CMTime duration = sourceAsset.duration;
    NSNumber *dur = [NSNumber numberWithFloat:CMTimeGetSeconds(duration)];
    [json setObject:dur forKey:@"duration"];
    NSString *jsonStr = [VVUtility convertNSDictToJSONString:json];
    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:VIDEO_COMING :jsonStr]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *path = [movieURL path];
        NSData *bytes = [[NSData alloc] initWithContentsOfFile:path];
        [socketHandler sendCommand:[[CommandWithValue alloc] init:VIDEODATA :bytes]];
    });
}

- (void)setPosition:(Command *)command{
    if ([command isKindOfClass:[CommandWithValue class]]) {
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
        NSString *JSONString = [[NSString alloc] initWithData:[command getData] encoding:NSUTF8StringEncoding];
        NSDictionary *json = [VVUtility getNSDictFromJSONString:JSONString];
        [sharedVars setDist:(int)[json valueForKey:@"dist"]];
        [sharedVars setYaw:(int)[json valueForKey:@"yaw"]];
        [sharedVars setPitch:(int)[json valueForKey:@"pitch"]];
    }
}

- (void)getPosition{
    CameraSettings *sharedVars = [CameraSettings sharedVariables];
    NSNumber *dst = [NSNumber numberWithInt: [sharedVars dist]];
    NSNumber *yw = [NSNumber numberWithInt: [sharedVars yaw]];
    NSNumber *ptch = [NSNumber numberWithInt: [sharedVars pitch]];
    NSArray *positions = [[NSArray alloc] initWithObjects:dst, yw, ptch, nil];
    NSArray *keys = [[NSArray alloc] initWithObjects:@"dist", @"yaw", @"pitch", nil];
    NSDictionary *pov = [[NSDictionary alloc] initWithObjects:positions forKeys:keys];
    NSString *jsonStr = [VVUtility convertNSDictToJSONString:pov];
    [socketHandler sendCommand:[[CommandWithValue alloc] initWithString:POSITION :jsonStr]];
}


// =============================================================================
#pragma mark - Gesture Handler

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {

    [self.captureManager setCameraSettings];
}


- (IBAction)switchToAimMode:(id)sender {
    if(mode != AIM_MODE){
        mode = AIM_MODE;
        [_logoView setHidden:YES];
        [_gridView setHidden:NO];
        [_aimMode setImage:[UIImage imageNamed:@"aim_mode_selected"] forState:UIControlStateNormal];
        [_cameraMode setImage:[UIImage imageNamed:@"camera_mode_off"] forState:UIControlStateNormal];
        [_logo.layer removeAllAnimations];
    }
}

- (IBAction)switchToCameraMode:(id)sender {
    if(mode != CAMERA_MODE && [socketHandler isConnectedToTCP]){
        mode = CAMERA_MODE;
        [_logoView setHidden:NO];
        _logo.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        [UIView animateWithDuration:4.0  delay:0 options:(UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat) animations:^{
            _logo.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
        } completion:nil];
        [_gridView setHidden:YES];
        [_aimMode setImage:[UIImage imageNamed:@"aim_mode_off"] forState:UIControlStateNormal];
        [_cameraMode setImage:[UIImage imageNamed:@"camera_mode_selected"] forState:UIControlStateNormal];
    }
}
@end
