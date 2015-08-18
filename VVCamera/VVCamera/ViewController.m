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
#import <AssetsLibrary/AssetsLibrary.h>


@interface ViewController ()
@property (nonatomic, strong) AVCaptureManager *captureManager;
@property (nonatomic, strong) StreamServer *streamServer;
@property (nonatomic, assign) NSTimer *timer;

@end


@implementation ViewController{
    VVNetworkSocketHandler *socketHandler;
    NSTimer *autoStopper;
    NSTimeInterval startTime;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
//    CGRect frame = self.view.frame;
//    frame.size.width = frame.size.width-_controlsView.frame.size.width;
//    _previewView.frame = frame;
    // TODO: Close camera and stuff when view disappears
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
    
    [self setCameraFramerate];
    
    self.streamServer = [[StreamServer alloc] init];
    [self.captureManager setStreamServer:self.streamServer];
    [self.streamServer startAcceptingConnections];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    socketHandler = [[VVNetworkSocketHandler alloc] init:1111 protocol:[[CameraProtocol alloc] init]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveProtocolNotification:)
                                                 name:@"ProtocolNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendJsonAndVideo)
                                                 name:@"StopNotification"
                                               object:nil];
    [self hideStatusBar];

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
               selector:@selector(wentToBackground)
                   name:@"Background"
                 object:nil];
    [center addObserver:self
               selector:@selector(cameToForeground)
                   name:@"Foreground"
                 object:nil];
}

- (void)wentToBackground{
    // TODO: close socket, stream stuff, camera?
    [socketHandler sendCommand:[[Command alloc] init:QUIT]];
}

- (void)cameToForeground{
    // TODO: restore what was closed when went to background
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
            // check version
            break;
        case WRONG_VERSION:
            break;
        case CAMERA_SETTINGS:
            // Camera settings stuff
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


@end
