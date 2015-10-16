//
//  AVCaptureManager.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVCaptureManager.h"
#import "CameraSettings.h"
#import "CommonNotificationNames.h"

#ifndef USE_AUDIO
//#define USE_AUDIO
#endif

static const CGSize kQVStreamSize = (CGSize) {
        .width = 320,
        .height = 180
};

@interface AVCaptureManager ()
        <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate> {
    CMTime defaultVideoMaxFrameDuration;
}


@property(nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, strong) dispatch_queue_t audioDataQueue;
@property(nonatomic, strong) dispatch_queue_t videoDataQueue;
@property(nonatomic, strong) dispatch_queue_t streamQueue;
@property(nonatomic, strong) dispatch_queue_t writingQueue;

@end

@implementation AVCaptureManager {
    NSTimer *timer;
    AVAssetWriter *writer;
    AVAssetWriterInput *videoInput;
    AVAssetWriterInput *audioInput;
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
    NSURL *fileURL;
    int64_t frameNumber;
    int64_t streamFrame;
    int32_t fps;
    int32_t streamfps;
    BOOL finishRecording;
}

- (instancetype)initWithPreviewView:(UIView *)previewView {
    self = [super init];
    if (self) {
        _isStreaming = NO;
        finishRecording = NO;
        _isRecording = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setStreamState:) name:kNNStream object:nil];
        self.videoDataQueue = dispatch_queue_create("videoDataQueue", DISPATCH_QUEUE_SERIAL);
        self.audioDataQueue = dispatch_queue_create("audioDataQueue", DISPATCH_QUEUE_SERIAL);
        self.writingQueue = dispatch_queue_create("writingQueue", DISPATCH_QUEUE_SERIAL);
        self.streamQueue = dispatch_queue_create("streamQueue", DISPATCH_QUEUE_SERIAL);
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
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

    if (error) {
        NSLog(@"Video input creation failed");
        return NO;
    }

    if (![self.captureSession canAddInput:videoIn]) {
        NSLog(@"Video input add-to-session failed");
        return NO;
    }
    [self.captureSession addInputWithNoConnections:videoIn];

    // save the default format
    self.defaultFormat = videoDevice.activeFormat;
    defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;

    [self setupVideoDataOutput:videoIn];

#ifdef USE_AUDIO
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (![self.captureSession canAddInput:audioIn]) {
        NSLog(@"Audio input add-to-session failed");
        return NO;
    }
    [self.captureSession addInput:audioIn];
    
    [self setupAudioDataOutput];
#endif
    [self prepareAssetWriter];

    [self.captureSession startRunning];
    return YES;
}

- (void)setupPreview:(UIView *)previewView {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    CGRect frame = previewView.frame;
    if (frame.size.width < frame.size.height) {
        CGPoint origin = previewView.frame.origin;
        frame = CGRectMake(origin.x, origin.y, previewView.frame.size.height, previewView.frame.size.width);
    }
    self.previewLayer.frame = frame;
    self.previewLayer.contentsGravity = kCAGravityResizeAspect;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self addPreview:previewView];
    AVCaptureConnection *connection = (self.previewLayer).connection;
    [self configureConnection:connection];
}

- (void)addPreview:(UIView *)previewView {
    [previewView.layer insertSublayer:self.previewLayer atIndex:0];
}

- (void)removePreview {
    [self.previewLayer removeFromSuperlayer];
}

- (AVCaptureConnection *)createVideoConnectionForOutput:(AVCaptureOutput *)output andInput:(AVCaptureDeviceInput *)videoIn {
    AVCaptureConnection *connection = [[AVCaptureConnection alloc] initWithInputPorts:videoIn.ports output:output];
    [self configureConnection:connection];
    return connection;
}

- (void)configureConnection:(AVCaptureConnection *)connection {
    if (connection.supportsVideoOrientation) {
        AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
        connection.videoOrientation = orientation;
    }
    if (connection.supportsVideoStabilization) {
        connection.preferredVideoStabilizationMode = [[CameraSettings sharedVariables] stabilizationMode];
    }
}

- (void)setupVideoDataOutput:(AVCaptureDeviceInput *)input {
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    videoDataOutput.videoSettings = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [videoDataOutput setSampleBufferDelegate:self queue:self.videoDataQueue];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    AVCaptureConnection *connection = [self createVideoConnectionForOutput:videoDataOutput andInput:input];
    if ([self.captureSession canAddOutput:videoDataOutput]) {
        [self.captureSession addOutputWithNoConnections:videoDataOutput];
        [self.captureSession addConnection:connection];
    }
}

- (void)setupAudioDataOutput {
    AVCaptureAudioDataOutput *audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioDataOutput setSampleBufferDelegate:self queue:self.audioDataQueue];
    if ([self.captureSession canAddOutput:audioDataOutput]) {
        [self.captureSession addOutput:audioDataOutput];
    }
}

- (void)setupVideoAssetWriterInput {
    NSDictionary *settings = @{AVVideoCodecKey : AVVideoCodecH264,
            AVVideoHeightKey : @720,
            AVVideoWidthKey : @1280};
    videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:settings];
    videoInput.expectsMediaDataInRealTime = YES;
    NSDictionary *pxlBufAttrs = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:videoInput sourcePixelBufferAttributes:pxlBufAttrs];
}

- (void)setupAudioAssetWriterInput {
    AudioChannelLayout stereoChannelLayout = {
            .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
            .mChannelBitmap = 0,
            .mNumberChannelDescriptions = 0
    };

    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];

    // Get the compression settings for 128 kbps AAC.
    NSDictionary *compressionAudioSettings = @{
            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
            AVEncoderBitRateKey : @128000,
            AVSampleRateKey : @44100,
            AVChannelLayoutKey : channelLayoutAsData,
            AVNumberOfChannelsKey : @2
    };

    // Create the asset writer input with the compression settings and specify the media type as audio.
    audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:compressionAudioSettings];
    audioInput.expectsMediaDataInRealTime = YES;
}

- (void)prepareAssetWriter {

    fileURL = [self generateFilePath];
    NSError *err;
    writer = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeMPEG4 error:&err];
    [self setupVideoAssetWriterInput];
    if ([writer canAddInput:videoInput]) {
        [writer addInput:videoInput];
    }

#ifdef USE_AUDIO
    [self setupAudioAssetWriterInput];
    if ([writer canAddInput:audioInput]){
        [writer addInput:audioInput];
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
        [self startStreaming];
    }
    else if ([msg isEqualToString:@"stop"]) {
        [self stopStreaming];
    }
}

- (void)startStreaming {
    streamFrame = 0;
    NSLog(@"Streaming started");
    _isStreaming = YES;
//    timer = [NSTimer scheduledTimerWithTimeInterval:0.07
//                                             target:self
//                                           selector:@selector(captureImage)
//                                           userInfo:nil
//                                            repeats:YES];
}

- (void)stopStreaming {
    _isStreaming = NO;
    NSLog(@"Streaming stopped");
//    [timer invalidate];
}

- (void)writeImageToSocket:(UIImage *)image withTimestamp:(NSTimeInterval)timestamp {
    GCDAsyncSocket *socket = _streamServer.connectedSocket;
    if (socket != nil) {
        NSData *imgAsJPEG = UIImageJPEGRepresentation(image, 0.1);
        NSString *content = [[NSString alloc] initWithFormat:@"%@%@%lu%@%@%lu%@",
                                                             @"Content-type: image/jpeg\r\n",
                                                             @"Content-Length: ",
                                                             (unsigned long) imgAsJPEG.length,
                                                             @"\r\n",
                                                             @"X-Timestamp:",
                                                             (unsigned long) timestamp,
                                                             @"\r\n\r\n"];
        NSString *end = [[NSString alloc] initWithFormat:@"%@%@%@",
                                                         @"\r\n--", kQVStreamBoundary, @"\r\n"];
        [socket writeData:[content dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
        [socket writeData:imgAsJPEG withTimeout:-1 tag:2];
        [socket writeData:[end dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-3 tag:3];
    }
    else {
        NSLog(@"socket was nil");
    }
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, YES, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
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
}

- (void)resetFormat {
    BOOL isRunning = self.captureSession.isRunning;
    if (isRunning) {
        [self.captureSession stopRunning];
    }

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    if ([videoDevice lockForConfiguration:&error]) {
        videoDevice.activeFormat = self.defaultFormat;
        videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
        [videoDevice unlockForConfiguration];
    }
    else {
        NSLog(@"%@", error.localizedDescription);
    }

    if (isRunning) {
        [self.captureSession startRunning];
    }
}

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS {
    BOOL isRunning = self.captureSession.isRunning;
    if (isRunning) {
        [self.captureSession stopRunning];
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
                fps = (int32_t) desiredFPS;
                streamfps = fps / 15;
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
        [self setCameraSettings:CGPointMake(0.5f, 0.5f)];
    }

    if (isRunning) {
        [self.captureSession startRunning];
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

- (void)startRecording {
    frameNumber = 0;
    _isRecording = YES;
    [writer startSessionAtSourceTime:kCMTimeZero];
    timer = [NSTimer scheduledTimerWithTimeInterval:15.1
                                             target:self
                                           selector:@selector(stopRecording)
                                           userInfo:nil
                                            repeats:NO];

//    NSURL *fileURL = [self generateFilePath];

//    CMTime fragmentInterval = CMTimeMake(1,1);
//    [self.fileOutput setMovieFragmentInterval:fragmentInterval];
//    [self.fileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)stopRecording {
    [timer invalidate];
    _isRecording = NO;
    finishRecording = YES;
//    [self.fileOutput stopRecording];
}

- (void)finishRecording {
    finishRecording = NO;
    [writer finishWritingWithCompletionHandler:^(void) {
        [[NSNotificationCenter defaultCenter]
                postNotificationName:@"StopNotification"
                              object:self
                            userInfo:@{@"file" : fileURL}];
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

#pragma mark delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//    if([captureOutput isKindOfClass:[AVCaptureVideoDataOutput class]]){
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (_isRecording && videoInput.readyForMoreMediaData) {
        if (![pixelBufferAdaptor appendPixelBuffer:imageBuffer withPresentationTime:CMTimeMake(frameNumber, fps)]) {
            NSLog(@"writing video failed");
        }
        else {
            frameNumber++;
        }
    }
    else if (!_isRecording && finishRecording) {
        [self finishRecording];
    }

    if (_isStreaming) {
        streamFrame++;
        if (streamFrame == streamfps) {
            CVImageBufferRef buf = (CVImageBufferRef) CFRetain(imageBuffer);
            dispatch_async(self.streamQueue, ^(void) {
                UIImage *image = [self imageFromSampleBuffer:buf];

                NSTimeInterval timestamp = [NSDate date].timeIntervalSince1970;
                image = [self imageWithImage:image scaledToSize:kQVStreamSize];
                [self writeImageToSocket:image withTimestamp:timestamp];
                CFRelease(buf);
            });
            streamFrame = 0;
        }

    }
//    }
//    else {
//        if (_isRecording && audioInput.readyForMoreMediaData) {
//            CMSampleBufferRef buf = (CMSampleBufferRef)CFRetain(sampleBuffer);
//            dispatch_async(self.writingQueue, ^(void){
//            if (![audioInput appendSampleBuffer:buf]) {
//                NSLog(@"writing audio failed");
//            }
//                CFRelease(buf);
//            });
//        }
//    }
}

// From https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/06_MediaRepresentations.html#//apple_ref/doc/uid/TP40010188-CH2-SW4
- (UIImage *)imageFromSampleBuffer:(CVImageBufferRef)imageBuffer {
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);

    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
            bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];

    // Release the Quartz image
    CGImageRelease(quartzImage);

    return (image);
}


@end
