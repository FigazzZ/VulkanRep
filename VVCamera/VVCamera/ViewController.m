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
#import "CameraVariables.h"
#import "VVUtility.h"
#import <AssetsLibrary/AssetsLibrary.h>


@interface ViewController ()
<AVCaptureManagerDelegate>
{
    NSTimeInterval startTime;
    BOOL isNeededToSave;
}
@property (nonatomic, strong) AVCaptureManager *captureManager;
@property (nonatomic, assign) NSTimer *timer;

@end


@implementation ViewController{
    VVNetworkSocketHandler *socketHandler;
    NSTimer *autoStopper;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
//    CGRect frame = self.view.frame;
//    frame.size.width = frame.size.width-_controlsView.frame.size.width;
//    _previewView.frame = frame;
    // TODO: Close camera and stuff when view disappears
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:_previewView];
    
    self.captureManager.delegate = self;
    
    [self setCameraFramerate];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    socketHandler = [[VVNetworkSocketHandler alloc] init:1111 protocol:[[CameraProtocol alloc] init]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveProtocolNotification:)
                                                 name:@"ProtocolNotification"
                                               object:nil];
    
    [self hideStatusBar];

}

- (void)viewDidDisappear:(BOOL)animated{
    [socketHandler sendCommand:[[Command alloc] init:QUIT]];
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
            // set position
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
            // delete video from phone
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void)startRecording{
    if(!_captureManager.isRecording){
        [_captureManager startRecording];
        [socketHandler sendCommand:[[Command alloc] init:OK]];
        autoStopper = [NSTimer scheduledTimerWithTimeInterval:16
                                         target:self
                                       selector:@selector(stopRecording)
                                       userInfo:nil
                                        repeats:NO];
        
    }
}

- (void)stopRecording{
    if(_captureManager.isRecording){
        [autoStopper invalidate];
        autoStopper = nil;
        [_captureManager stopRecording];
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        CameraVariables *sharedVars = [CameraVariables sharedVariables];
        // TODO: calculate delay if possible
        NSDictionary *pov = [sharedVars getPositionJson];
        NSNumber *fps = [NSNumber numberWithFloat:[sharedVars framerate]];
        [json setObject:fps forKey:@"fps"];
        [json setObject:pov forKey:@"pointOfView"];
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
}

- (void)setPosition:(Command *)command{
    if ([command isKindOfClass:[CommandWithValue class]]) {
        CameraVariables *sharedVars = [CameraVariables sharedVariables];
        NSString *JSONString = [[NSString alloc] initWithData:[command getData] encoding:NSUTF8StringEncoding];
        NSDictionary *json = [VVUtility getNSDictFromJSONString:JSONString];
        [sharedVars setDist:(int)[json valueForKey:@"dist"]];
        [sharedVars setYaw:(int)[json valueForKey:@"yaw"]];
        [sharedVars setPitch:(int)[json valueForKey:@"pitch"]];
    }
}

- (void)getPosition{
    CameraVariables *sharedVars = [CameraVariables sharedVariables];
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

    [self.captureManager toggleContentsGravity];
}


// =============================================================================
#pragma mark - Private


- (void)saveRecordedFile:(NSURL *)recordedFile {
    
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:
         ^(NSURL *assetURL, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 
                 NSString *title;
                 NSString *message;
                 
                 if (error != nil) {
                     
                     title = @"Failed to save video";
                     message = [error localizedDescription];
                 }
                 else {
                     title = @"Saved!";
                     message = nil;
                 }
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             });
         }];
    });
}



// =============================================================================
#pragma mark - Timer Handler

- (void)timerHandler:(NSTimer *)timer {
    
//    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
//    NSTimeInterval recorded = current - startTime;
}



// =============================================================================
#pragma mark - AVCaptureManagerDeleagte

- (void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL error:(NSError *)error {
    
    if (error) {
        NSLog(@"error:%@", error);
        return;
    }
    
    if (!isNeededToSave) {
        return;
    }
    
    // TODO: Get bytes and send video to server
    [self saveRecordedFile:outputFileURL];
}


// =============================================================================
#pragma mark - IBAction

- (IBAction)recButtonTapped:(id)sender {
    
    // REC START
    if (!self.captureManager.isRecording) {
        
        // timer start
        startTime = [[NSDate date] timeIntervalSince1970];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                      target:self
                                                    selector:@selector(timerHandler:)
                                                    userInfo:nil
                                                     repeats:YES];

        [self.captureManager startRecording];
    }
    // REC STOP
    else {

        isNeededToSave = YES;
        [self.captureManager stopRecording];
        
        [self.timer invalidate];
        self.timer = nil;
    }
}

//- (IBAction)retakeButtonTapped:(id)sender {
//    
//    isNeededToSave = NO;
//    [self.captureManager stopRecording];
//
//    [self.timer invalidate];
//    self.timer = nil;
//    
//    self.statusLabel.text = nil;
//}

@end
