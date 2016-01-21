//
//  AVCaptureManager.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVCaptureManager.h"
#import "CameraSettings.h"
#import "CamNotificationNames.h"
#import "VideoOutput.h"
#import "AudioOutput.h"

#ifndef USE_AUDIO
//#define USE_AUDIO
#endif

static const unsigned long kQVCameraSettingDelay = 100000000; // 100ms

@interface AVCaptureManager () {
    CMTime defaultVideoMaxFrameDuration;
}


@property(nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
//@property(nonatomic, strong) dispatch_queue_t writingQueue;

@end

@implementation AVCaptureManager {
    NSTimer *timer;
    AVAssetWriter *writer;
    AudioOutput *audioOutput;
    VideoOutput *videoOutput;
    BOOL videoWritingFinished;
    BOOL audioWritingFinished;
    NSURL *fileURL;
    double lux;
}

- (instancetype)initWithPreviewView:(UIView *)previewView {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setStreamState:) name:kNNStream object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishRecording:) name:kNNFinishRecording object:nil];
        //        _writingQueue = dispatch_queue_create("writingQueue", DISPATCH_QUEUE_SERIAL);
        videoWritingFinished = NO;
        audioWritingFinished = NO;
        if (![self setupCaptureSession]) {
            return nil;
        }
        if (previewView != nil) {
            [self setupPreview:previewView];
        }
    }
    return self;
}

- (BOOL)setupCaptureSession {

    NSError *error;
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

    if (error) {
        NSLog(@"Video input creation failed");
        return NO;
    }

    if (![_captureSession canAddInput:videoIn]) {
        NSLog(@"Video input add-to-session failed");
        return NO;
    }
    [_captureSession addInputWithNoConnections:videoIn];

    // save the default format
    _defaultFormat = videoDevice.activeFormat;
    defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;

    videoOutput = [[VideoOutput alloc] initWithInput:videoIn];
    if ([_captureSession canAddOutput:videoOutput.dataOutput]) {
        [_captureSession addOutputWithNoConnections:videoOutput.dataOutput];
        [_captureSession addConnection:videoOutput.connection];
    }

#ifdef USE_AUDIO
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (![_captureSession canAddInput:audioIn]) {
        NSLog(@"Audio input add-to-session failed");
        return NO;
    }
    [_captureSession addInput:audioIn];
    
    audioOutput = [[AudioOutput alloc] init];
    if ([_captureSession canAddOutput:audioOutput.dataOutput]) {
        [_captureSession addOutput:audioOutput.dataOutput];
    }

#endif
    [self prepareAssetWriter];

    [_captureSession startRunning];
    return YES;
}

- (void)setupPreview:(UIView *)previewView {
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CGRect frame = previewView.frame;
    if (frame.size.width < frame.size.height) {
        CGPoint origin = previewView.frame.origin;
        frame = CGRectMake(origin.x, origin.y, previewView.frame.size.height, previewView.frame.size.width);
    }
    _previewLayer.frame = frame;
    _previewLayer.contentsGravity = kCAGravityResizeAspect;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [previewView.layer insertSublayer:_previewLayer atIndex:0];
    AVCaptureConnection *connection = (_previewLayer).connection;
    [VideoOutput configureVideoConnection:connection];
}

- (void)addPreview:(UIView *)previewView {
    if (_captureSession.running) {
        [_captureSession stopRunning];
    }
    [self setupPreview:previewView];
    [_captureSession startRunning];
}

- (void)removePreview {
    if (_captureSession.running) {
        [_captureSession stopRunning];
    }
    [_captureSession removeConnection:_previewLayer.connection];
    [_previewLayer removeFromSuperlayer];
    _previewLayer = nil;
    [_captureSession startRunning];
}

- (void)setStreamServer:(StreamServer *)server {
    _streamServer = server;
    if (videoOutput != nil) {
        videoOutput.streamServer = server;
    }
}

- (void)startCaptureSession {
    if (_captureSession != nil && !_captureSession.running) {
        [_captureSession startRunning];
    }
}

- (void)stopCaptureSession {
    if (_captureSession != nil && _captureSession.running) {
        [_captureSession stopRunning];
    }
}


- (void)prepareAssetWriter {
    fileURL = [self generateFilePath];
    NSError *err;
    writer = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeMPEG4 error:&err];
    [videoOutput setupVideoAssetWriterInput];
    if ([writer canAddInput:videoOutput.videoWriterInput]) {
        [writer addInput:videoOutput.videoWriterInput];
    }

#ifdef USE_AUDIO
    [audioOutput setupAudioAssetWriterInput];
    if ([writer canAddInput:audioOutput.audioWriterInput]){
        [writer addInput:audioOutput.audioWriterInput];
    }
#endif
    [writer startWriting];
}

- (void)closeAssetWriter {
    @try {
        if (writer.status == AVAssetWriterStatusWriting) {
            [writer finishWritingWithCompletionHandler:^{
                [AVCaptureManager deleteVideo:fileURL];
            }];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Closing the assetwriter failed");
    }
}

// ====================================================
#pragma mark Streaming


- (void)setStreamState:(NSNotification *)notification {
    NSDictionary *cmdDict = notification.userInfo;
    NSString *msg = cmdDict[@"message"];
    if ([msg isEqualToString:@"start"]) {
        [videoOutput startStreaming];
    }
    else if ([msg isEqualToString:@"stop"]) {
        [videoOutput stopStreaming];
    }
}

- (BOOL)isStreaming {
    return videoOutput.isStreaming;
}

// =============================================================================
#pragma mark - Public

- (void)setCameraSettings:(CGPoint)point {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    if ([videoDevice lockForConfiguration:&error]) {
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
        if ([videoDevice isExposureModeSupported:sharedVars.exposureMode]) {
            if (videoDevice.exposurePointOfInterestSupported) {
                videoDevice.exposurePointOfInterest = point;
            }
            videoDevice.exposureMode = sharedVars.exposureMode;
        }

        if ([videoDevice isFocusModeSupported:sharedVars.focusMode]) {
//            if (videoDevice.focusPointOfInterestSupported) {
//                videoDevice.focusPointOfInterest = point;
//            }
            videoDevice.focusMode = sharedVars.focusMode;
        }

        if (videoDevice.smoothAutoFocusSupported) {
            videoDevice.smoothAutoFocusEnabled = sharedVars.smoothFocusEnabled;
        }
        if (videoDevice.autoFocusRangeRestrictionSupported) {
            videoDevice.autoFocusRangeRestriction = sharedVars.autoFocusRange;
        }
        if ([videoDevice isWhiteBalanceModeSupported:sharedVars.wbMode]) {
            videoDevice.whiteBalanceMode = sharedVars.wbMode;
        }
        [videoDevice unlockForConfiguration];
    }
    else {
        NSLog(@"%@", error.localizedDescription);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kQVCameraSettingDelay), dispatch_get_main_queue(), ^{
        lux = pow(videoDevice.lensAperture, 2) / (CMTimeGetSeconds(videoDevice.exposureDuration) * videoDevice.ISO);
        [self setShutterSpeed];
    });

}

- (void)setShutterSpeed {
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;

    if ([videoDevice lockForConfiguration:&error]) {
        CameraSettings *sharedVars = [CameraSettings sharedVariables];
        CMTime newSpeed = CMTimeMake(1, (int32_t) sharedVars.shutterSpeed);
        double nISO = pow(videoDevice.lensAperture, 2) / (CMTimeGetSeconds(newSpeed) * lux);
        double setISO = MIN(MAX(nISO, videoDevice.activeFormat.minISO), videoDevice.activeFormat.maxISO);
        [videoDevice setExposureModeCustomWithDuration:newSpeed ISO:setISO completionHandler:nil];
        [videoDevice unlockForConfiguration];
        NSLog(@"Shutterspeed changed to 1/%d", sharedVars.shutterSpeed);
    }
}

- (void)resetFormat {
    BOOL isRunning = _captureSession.isRunning;
    if (isRunning) {
        [_captureSession stopRunning];
    }

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    if ([videoDevice lockForConfiguration:&error]) {
        videoDevice.activeFormat = _defaultFormat;
        videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
        [videoDevice unlockForConfiguration];
    }
    else {
        NSLog(@"%@", error.localizedDescription);
    }

    if (isRunning) {
        [_captureSession startRunning];
    }
}

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS {
    BOOL isRunning = _captureSession.isRunning;
    if (isRunning) {
        [_captureSession stopRunning];
    }

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int32_t maxWidth = 0;
    BOOL framerateChanged = NO;

    for (AVCaptureDeviceFormat *format in videoDevice.formats) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            CMFormatDescriptionRef desc = format.formatDescription;
            int32_t width = (CMVideoFormatDescriptionGetDimensions(desc)).width;

            if (range.minFrameRate <= desiredFPS && desiredFPS <= range.maxFrameRate && width >= maxWidth) {
                selectedFormat = format;
                maxWidth = width;
                [[CameraSettings sharedVariables] setFramerate:desiredFPS];
                videoOutput.videoFPS = (int32_t) desiredFPS;
                framerateChanged = YES;
            }
        }
    }

    if (selectedFormat != nil) {
        NSError *error;
        if ([videoDevice lockForConfiguration:&error]) {
            NSLog(@"selected format:%@", selectedFormat);
            videoDevice.activeFormat = selectedFormat;
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t) desiredFPS);
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t) desiredFPS);
            [videoDevice unlockForConfiguration];
        }
        else {
            NSLog(@"%@", error.localizedDescription);
        }
        //[self setCameraSettings:CGPointMake(0.5f, 0.5f)];
    }

    if (isRunning) {
        [_captureSession startRunning];
    }
    return framerateChanged;
}

- (NSURL *)generateFilePath {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd-HH-mm-ss";
    NSString *dateTimePrefix = [formatter stringFromDate:[NSDate date]];

    int fileNamePostfix = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *filePath = nil;
    do {
        filePath = [NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
    } while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);

    return [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
}

- (BOOL)isRecording {

#ifdef USE_AUDIO
    return videoOutput.isRecording && audioOutput.isRecording;
#else
    return videoOutput.isRecording;
#endif
}

- (void)startRecording {
    videoOutput.isRecording = YES;

#ifdef USE_AUDIO
    audioOutput.isRecording = YES;
#endif
    [writer startSessionAtSourceTime:kCMTimeZero];
    timer = [NSTimer scheduledTimerWithTimeInterval:15.1
                                             target:self
                                           selector:@selector(stopRecording)
                                           userInfo:nil
                                            repeats:NO];
}

- (void)stopRecording {
    [timer invalidate];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNNStopOK object:self userInfo:nil];
    videoOutput.isRecording = NO;
#ifdef USE_AUDIO
    audioOutput.isRecording = NO;
#endif
}

- (void)finishRecording:(NSNotification *)notification {
#ifdef USE_AUDIO
    if([notification.object isKindOfClass:VideoOutput.class]){
        videoWritingFinished = YES;
    }
    else {
        audioWritingFinished = YES;
    }
    
    if (!(videoWritingFinished && audioWritingFinished)) {
        return;
    }
#endif
    [writer finishWritingWithCompletionHandler:^(void) {
        [[NSNotificationCenter defaultCenter]
                postNotificationName:kNNStopRecording
                              object:self
                            userInfo:@{@"file" : fileURL}];
        videoWritingFinished = NO;
        audioWritingFinished = NO;
        [self prepareAssetWriter];

    }];
}

- (NSURL *)getVideoFile {
    return fileURL;
}

+ (void)deleteVideo:(NSURL *)file {
    NSLog(@"Deleting video");
    NSFileManager *manager = [NSFileManager defaultManager];

    NSError *error = nil;

    NSString *path = file.path;
    [manager removeItemAtPath:path error:&error];
    // TODO: check error
}


@end