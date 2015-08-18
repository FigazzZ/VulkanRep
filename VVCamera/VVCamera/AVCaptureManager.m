//
//  AVCaptureManager.m
//  SlowMotionVideoRecorder
//  https://github.com/shu223/SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "AVCaptureManager.h"
#import "CameraSettings.h"
#import <AssetsLibrary/AssetsLibrary.h>


@interface AVCaptureManager ()
<AVCaptureFileOutputRecordingDelegate>
{
    CMTime defaultVideoMaxFrameDuration;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *fileOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *streamOutput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t videoDataQueue;

@end


@implementation AVCaptureManager{
    NSTimer *timer;
    CGSize size;
}

- (id)initWithPreviewView:(UIView *)previewView {
    
    self = [super init];
    
    if (self) {
        size = CGSizeMake(320, 180);
        NSError *error;
        
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
        
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error) {
            NSLog(@"Video input creation failed");
            return nil;
        }
        
        if (![self.captureSession canAddInput:videoIn]) {
            NSLog(@"Video input add-to-session failed");
            return nil;
        }
        [self.captureSession addInputWithNoConnections:videoIn];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(receiveStreamNotification:)
                                                     name:@"StreamNotification"
                                                   object:nil];
        
        // save the default format
        self.defaultFormat = videoDevice.activeFormat;
        defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;
        
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
//        AVCaptureDevice *audioDevice= [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
//        AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
//        [self.captureSession addInput:audioIn];
        
        
        // If you wish to cap the frame rate to a known value, such as 15 fps, set
        // minFrameDuration.
        // TODO: replace with non-deprecated function
        // http://stackoverflow.com/questions/8058891/avcapturesession-with-multiple-outputs/22037685#22037685
        
        
        self.streamOutput = [[AVCaptureStillImageOutput alloc] init];
        [self.streamOutput setHighResolutionStillImageOutputEnabled:NO];
        self.videoDataQueue = dispatch_queue_create("streamQueue", DISPATCH_QUEUE_SERIAL);
        
        if ([self.captureSession canAddOutput:self.streamOutput])
        {
            [self.streamOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [self.captureSession addOutput:self.streamOutput];
        }

        
        self.fileOutput = [[AVCaptureMovieFileOutput alloc] init];
        [self.fileOutput setMaxRecordedDuration:CMTimeMake(15, 1)];
        AVCaptureConnection *connection = [[AVCaptureConnection alloc] initWithInputPorts:[videoIn ports] output:self.fileOutput];
        if ([connection isVideoOrientationSupported])
        {
            AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
            [connection setVideoOrientation:orientation];
        }
        if([connection isVideoStabilizationSupported]){
            connection.preferredVideoStabilizationMode = [sharedVars stabilizationMode];
        }
        [self.captureSession addOutputWithNoConnections:self.fileOutput];
        [self.captureSession addConnection:connection];
        
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        CGRect frame = previewView.frame;
        if(frame.size.width < frame.size.height){
            CGPoint origin = previewView.frame.origin;
            frame = CGRectMake(origin.x, origin.y, previewView.frame.size.height, previewView.frame.size.width);
        }
        self.previewLayer.frame = frame;
        self.previewLayer.contentsGravity = kCAGravityResizeAspect;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [previewView.layer insertSublayer:self.previewLayer atIndex:0];
        AVCaptureConnection *connection2 = [self.previewLayer connection];
        if ([connection2 isVideoOrientationSupported])
        {
            AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
            [connection2 setVideoOrientation:orientation];
        }
        if([connection2 isVideoStabilizationSupported]){
            connection2.preferredVideoStabilizationMode = [sharedVars stabilizationMode];
        }
        [self.captureSession startRunning];
    }
    return self;
}

- (void)receiveStreamNotification:(NSNotification *) notification{
    NSDictionary *cmdDict = [notification userInfo];
    NSString *msg = [cmdDict objectForKey:@"message"];
    if ([msg isEqualToString:@"start"]){
        [self startStreaming];
    }
    else if([msg isEqualToString:@"stop"]){
        [self stopStreaming];
    }
}


// =============================================================================
#pragma mark - Public

- (void)setCameraSettings {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [videoDevice lockForConfiguration:nil];
    CameraSettings *sharedVars = [CameraSettings sharedVariables];
    
    if([videoDevice isExposureModeSupported:[sharedVars exposureMode]]){
        videoDevice.exposureMode = [sharedVars exposureMode];
    }
    if([videoDevice isFocusModeSupported:[sharedVars focusMode]]){
        videoDevice.focusMode = [sharedVars focusMode];
    }
    if([videoDevice isSmoothAutoFocusSupported]){
        videoDevice.smoothAutoFocusEnabled = [sharedVars smoothFocusEnabled];
    }
    if([videoDevice isAutoFocusRangeRestrictionSupported]){
        videoDevice.autoFocusRangeRestriction = [sharedVars autoFocusRange];
    }
    if([videoDevice isWhiteBalanceModeSupported:[sharedVars wbMode]]){
        videoDevice.whiteBalanceMode = [sharedVars wbMode];
    }
    [videoDevice unlockForConfiguration];
   
    
}

- (void)startStreaming{
    timer = [NSTimer scheduledTimerWithTimeInterval:0.07
                                             target:self
                                           selector:@selector(captureImage)
                                           userInfo:nil
                                            repeats:YES];
}

- (void)stopStreaming{
    [timer invalidate];
}

- (void)captureImage{
    dispatch_async([self videoDataQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self streamOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[self.previewLayer connection] videoOrientation]];
        
        // Capture a still image.
        [[self streamOutput] captureStillImageAsynchronouslyFromConnection:[[self streamOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
            if (imageDataSampleBuffer)
            {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [self imageWithImage:[[UIImage alloc] initWithData:imageData] scaledToSize:size];
                GCDAsyncSocket *socket = [_streamServer connectedSocket];
                if(socket != nil){
                    NSString *content = [[NSString alloc] initWithFormat:@"%@%@%lu%@%@%lu%@",
                                         @"Content-type: image/jpeg\r\n",
                                         @"Content-Length: ",
                                         (unsigned long)[imageData length],
                                         @"\r\n",
                                         @"X-Timestamp:",
                                         (unsigned long)timestamp,
                                         @"\r\n\r\n"];
                    NSString *end = [[NSString alloc] initWithFormat:@"%@%@%@",
                                     @"\r\n--", BOUNDARY, @"\r\n"];
                    [socket writeData:[content dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
                    [socket writeData:UIImageJPEGRepresentation(image, 0.1) withTimeout:-1 tag:1];
                    [socket writeData:[end dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
                    
                }
//                UIImage *image = [[UIImage alloc] initWithData:imageData];
//                [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
            }
        }];
    });
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)setPreviewFrame:(CGRect)frame{
    self.previewLayer.frame = frame;
}

- (void)resetFormat {

    BOOL isRunning = self.captureSession.isRunning;
    
    if (isRunning) {
        [self.captureSession stopRunning];
    }

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [videoDevice lockForConfiguration:nil];
    videoDevice.activeFormat = self.defaultFormat;
    videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
    [videoDevice unlockForConfiguration];

    if (isRunning) {
        [self.captureSession startRunning];
    }
}

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS
{
    BOOL isRunning = self.captureSession.isRunning;
    BOOL framerateChanged = NO;
    
    if (isRunning)  [self.captureSession stopRunning];
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int32_t maxWidth = 0;
    AVFrameRateRange *frameRateRange = nil;

    for (AVCaptureDeviceFormat *format in [videoDevice formats]) {
        
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            
            CMFormatDescriptionRef desc = format.formatDescription;
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(desc);
            int32_t width = dimensions.width;

            if (range.minFrameRate <= desiredFPS && desiredFPS <= range.maxFrameRate && width >= maxWidth) {
                
                selectedFormat = format;
                frameRateRange = range;
                maxWidth = width;
                [[CameraSettings sharedVariables] setFramerate:desiredFPS];
                framerateChanged = YES;
            }
        }
    }
    
    if (selectedFormat) {
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
        if ([videoDevice lockForConfiguration:nil]) {
            
            NSLog(@"selected format:%@", selectedFormat);
            videoDevice.activeFormat = selectedFormat;
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            if([videoDevice isExposureModeSupported:[sharedVars exposureMode]]){
                videoDevice.exposureMode = [sharedVars exposureMode];
            }
            if([videoDevice isFocusModeSupported:[sharedVars focusMode]]){
                videoDevice.focusMode = [sharedVars focusMode];
            }
            if([videoDevice isSmoothAutoFocusSupported]){
                videoDevice.smoothAutoFocusEnabled = [sharedVars smoothFocusEnabled];
            }
            if([videoDevice isAutoFocusRangeRestrictionSupported]){
                videoDevice.autoFocusRangeRestriction = [sharedVars autoFocusRange];
            }
            if([videoDevice isWhiteBalanceModeSupported:[sharedVars wbMode]]){
                videoDevice.whiteBalanceMode = [sharedVars wbMode];
            }
            [videoDevice unlockForConfiguration];
        }
    }
    
    if (isRunning) [self.captureSession startRunning];
    return framerateChanged;
}

- (void)startRecording {
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString* dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    int fileNamePostfix = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = nil;
    do
        filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
    while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    
    NSURL *fileURL = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
    
    CMTime fragmentInterval = CMTimeMake(1,1);
    [self.fileOutput setMovieFragmentInterval:fragmentInterval];
    [self.fileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)stopRecording {

    [self.fileOutput stopRecording];
}

- (NSURL *)getVideoFile{
    return [self.fileOutput outputFileURL];
}

// =============================================================================
#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray *)connections
{
    _isRecording = YES;
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
   didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                       fromConnections:(NSArray *)connections error:(NSError *)error
{
    _isRecording = NO;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"StopNotification"
     object:self
     userInfo:nil];
}

@end
