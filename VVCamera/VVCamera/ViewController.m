//
//  ViewController.m
//  SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"
#import "AVCaptureManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "VVNetworkSocketHandler.h"
#import "CameraProtocol.h"
#import "CommandType.h"
#import "Command.h"
#import "CommandWithValue.h"


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
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.captureManager = [[AVCaptureManager alloc] initWithPreviewView:self.view];
    
    self.captureManager.delegate = self;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    socketHandler = [[VVNetworkSocketHandler alloc] init:1111 protocol:[[CameraProtocol alloc] init]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveProtocolNotification:)
                                                 name:@"ProtocolNotification"
                                               object:nil];
    // Setup images for the Shutter Button

    //self.outerImageView.image = self.outerImage1;

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

- (void) startRecording{
    if(!_captureManager.isRecording){
        [_captureManager startRecording];
        [socketHandler sendCommand:[[Command alloc] init:OK]];
    }
}

- (void) stopRecording{
    if(_captureManager.isRecording){
        [_captureManager stopRecording];
        // TODO: build json and stuff
        //[socketHandler sendCommand:[[Command alloc] init:OK]];
    }
}

- (void) getPosition{
    
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

- (IBAction)fpsChanged:(UISegmentedControl *)sender {
    
    // Switch FPS
    
//    CGFloat desiredFps = 0.0;;
//    switch (self.fpsControl.selectedSegmentIndex) {
//        case 0:
//        default:
//        {
//            break;
//        }
//        case 1:
//            desiredFps = 60.0;
//            break;
//        case 2:
//            desiredFps = 120.0;
//            break;
//    }
    
    
        
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    dispatch_async(queue, ^{
//        
//        if (desiredFps > 0.0) {
//            [self.captureManager switchFormatWithDesiredFPS:desiredFps];
//        }
//        else {
//            [self.captureManager resetFormat];
//        }
//        
//        dispatch_async(dispatch_get_main_queue(), ^{
//
//            if (desiredFps > 30.0) {
//                self.outerImageView.image = self.outerImage2;
//            }
//            else {
//                self.outerImageView.image = self.outerImage1;
//            }
//        });
//    });
}

@end
