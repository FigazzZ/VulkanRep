//
//  AVCaptureManager.m
//  VVCamera
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "AVCaptureManager.h"
#import "CameraSettings.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface AVCaptureManager ()
//<AVCaptureFileOutputRecordingDelegate>
//{
//    CMTime defaultVideoMaxFrameDuration;
//}
<AVCaptureVideoDataOutputSampleBufferDelegate>{
    CMTime defaultVideoMaxFrameDuration;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *fileOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *streamOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t videoDataQueue;
@property (nonatomic, strong) dispatch_queue_t streamQueue;

@end


@implementation AVCaptureManager{
    NSTimer *timer;
    CGSize size;
    SystemSoundID soundID;
    AVAssetWriter *writer;
    AVAssetWriterInput *writerInput;
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
    NSURL *fileURL;
    int64_t frameNumber;
    int64_t streamFrame;
    int32_t fps;
    int32_t streamfps;
    BOOL finishRecording;
}

- (id)initWithPreviewView:(UIView *)previewView {
    
    self = [super init];
    
    if (self) {
        _isStreaming = NO;
        finishRecording = NO;
        _isRecording = NO;
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
        
        self.videoDataQueue = dispatch_queue_create("videoDataQueue", DISPATCH_QUEUE_SERIAL);
        self.streamQueue = dispatch_queue_create("streamQueue", DISPATCH_QUEUE_SERIAL);
        // save the default format
        self.defaultFormat = videoDevice.activeFormat;
        defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;

        [self setupVideoDataOutput:videoIn];
        
//        [self setupFileOutput:videoIn];
//        [self setupStillImageStream];
        
        
        [self setupPreview:previewView];
        [self.captureSession startRunning];
        
        
//        NSString *path = [[NSBundle mainBundle] pathForResource:@"photoShutter2" ofType:@"caf"];
//        NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
//        AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &soundID);
    }
    return self;
}

- (void)setupPreview:(UIView *)previewView{
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    CGRect frame = previewView.frame;
    if(frame.size.width < frame.size.height){
        CGPoint origin = previewView.frame.origin;
        frame = CGRectMake(origin.x, origin.y, previewView.frame.size.height, previewView.frame.size.width);
    }
    self.previewLayer.frame = frame;
    self.previewLayer.contentsGravity = kCAGravityResizeAspect;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self addPreview:previewView];
    AVCaptureConnection *connection = [self.previewLayer connection];
    [self configureConnection:connection];
}

- (void)addPreview:(UIView *)previewView{
    [previewView.layer insertSublayer:self.previewLayer atIndex:0];
}

- (void)removePreview{
    [self.previewLayer removeFromSuperlayer];
}

- (AVCaptureConnection *)createVideoConnectionForOutput:(AVCaptureOutput *)output andInput:(AVCaptureDeviceInput *)videoIn {
    AVCaptureConnection *connection = [[AVCaptureConnection alloc] initWithInputPorts:[videoIn ports] output:output];
    [self configureConnection:connection];
    return connection;
}

- (void)configureConnection:(AVCaptureConnection *)connection{
    if ([connection isVideoOrientationSupported])
    {
        AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
        [connection setVideoOrientation:orientation];
    }
    if([connection isVideoStabilizationSupported]){
        connection.preferredVideoStabilizationMode = [[CameraSettings sharedVariables] stabilizationMode];
    }
}

- (void)setupFileOutput:(AVCaptureDeviceInput *)videoIn{
    self.fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [self.fileOutput setMaxRecordedDuration:CMTimeMake(15, 1)];
    AVCaptureConnection *connection = [self createVideoConnectionForOutput:self.fileOutput andInput:videoIn];
    if([self.captureSession canAddOutput:self.fileOutput]){
        [self.captureSession addOutputWithNoConnections:self.fileOutput];
        [self.captureSession addConnection:connection];
    }
}

- (void)setupStillImageStream{
    self.streamOutput = [[AVCaptureStillImageOutput alloc] init];
    [self.streamOutput setHighResolutionStillImageOutputEnabled:NO];
    
    if ([self.captureSession canAddOutput:self.streamOutput])
    {
        [self.streamOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
        [self.captureSession addOutput:self.streamOutput];
    }
}

- (void)setupVideoDataOutput:(AVCaptureDeviceInput *)input{
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    self.videoDataOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataQueue];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    AVCaptureConnection *connection = [self createVideoConnectionForOutput:self.videoDataOutput andInput:input];
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutputWithNoConnections:self.videoDataOutput];
        [self.captureSession addConnection:connection];
    }
    [self setupAssetWriter];
}

- (void)setupAssetWriter{
    NSDictionary *settings = @{AVVideoCodecKey : AVVideoCodecH264,
                               AVVideoHeightKey : [NSNumber numberWithInt:720],
                               AVVideoWidthKey : [NSNumber numberWithInt:1280]};
    writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:settings];
    writerInput.expectsMediaDataInRealTime = YES;
    NSDictionary *pxlBufAttrs = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput sourcePixelBufferAttributes:pxlBufAttrs];
    [self prepareAssetWriter];
}

- (void)prepareAssetWriter{
    fileURL = [self generateFilePath];
    NSError *err;
    writer = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeMPEG4 error:&err];
    [writer addInput:writerInput];
    [writer startWriting];
}

- (void)closeAssetWriter{
    [writer finishWritingWithCompletionHandler:^{
        [AVCaptureManager deleteVideo:fileURL];
    }];
}

// ====================================================
#pragma mark Streaming


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

- (void)startStreaming{
    _isStreaming = YES;
    streamFrame = 0;
//    timer = [NSTimer scheduledTimerWithTimeInterval:0.07
//                                             target:self
//                                           selector:@selector(captureImage)
//                                           userInfo:nil
//                                            repeats:YES];
}

- (void)stopStreaming{
    _isStreaming = NO;
//    [timer invalidate];
}

- (void)captureImage{
    dispatch_async([self videoDataQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self streamOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[self.previewLayer connection] videoOrientation]];
        //        AudioServicesPlaySystemSound(soundID);
        
        // Capture a still image.
        [[self streamOutput] captureStillImageAsynchronouslyFromConnection:[[self streamOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
            if (imageDataSampleBuffer)
            {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [self imageWithImage:[[UIImage alloc] initWithData:imageData] scaledToSize:size];
                [self writeImageToSocket:image withTimestamp:timestamp];
            }
        }];
    });
}

- (void)writeImageToSocket:(UIImage *)image withTimestamp:(NSTimeInterval)timestamp{
    GCDAsyncSocket *socket = [_streamServer connectedSocket];
    if(socket != nil){
        NSData *imgAsJPEG = UIImageJPEGRepresentation(image, 0.1);
        NSString *content = [[NSString alloc] initWithFormat:@"%@%@%lu%@%@%lu%@",
                             @"Content-type: image/jpeg\r\n",
                             @"Content-Length: ",
                             (unsigned long)[imgAsJPEG length],
                             @"\r\n",
                             @"X-Timestamp:",
                             (unsigned long)timestamp,
                             @"\r\n\r\n"];
        NSString *end = [[NSString alloc] initWithFormat:@"%@%@%@",
                         @"\r\n--", BOUNDARY, @"\r\n"];
        [socket writeData:[content dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        [socket writeData:imgAsJPEG withTimeout:-1 tag:1];
        [socket writeData:[end dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
    }
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
                fps = desiredFPS;
                streamfps = fps/15;
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

- (NSURL *)generateFilePath {
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString* dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    int fileNamePostfix = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = nil;
    do {
        filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
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

- (void)finishRecording{
    
    finishRecording = NO;
    [writer finishWritingWithCompletionHandler:^(void){
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"StopNotification"
         object:self
         userInfo:[[NSDictionary alloc] initWithObjects:@[fileURL] forKeys:@[@"file"]]];
        [self setupAssetWriter];
    }];
}

- (NSURL *)getVideoFile{
    return fileURL;
}

+ (void)deleteVideo:(NSURL *)file{
    NSLog(@"Deleting video");
    NSFileManager *manager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    
    NSString *path = [file path];
    [manager removeItemAtPath:path error:&error];
    // TODO: check error
}

#pragma mark delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (_isRecording && writerInput.readyForMoreMediaData){
        [pixelBufferAdaptor appendPixelBuffer:imageBuffer withPresentationTime:CMTimeMake(frameNumber, fps)];
        frameNumber++;
    }
    else if(!_isRecording && finishRecording){
        [self finishRecording];
    }
    
    if(_isStreaming && streamFrame == streamfps){
        CVImageBufferRef buf = (CVImageBufferRef)CFRetain(imageBuffer);
        dispatch_async(self.streamQueue, ^(void){
            UIImage *image = [self imageFromSampleBuffer:buf];
            
            NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
            image = [self imageWithImage:image scaledToSize:size];
            [self writeImageToSocket:image withTimestamp:timestamp];
            CFRelease(buf);
        });
        streamFrame = 0;
    }
    streamFrame++;
}

// From https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/06_MediaRepresentations.html#//apple_ref/doc/uid/TP40010188-CH2-SW4
- (UIImage *) imageFromSampleBuffer:(CVImageBufferRef) imageBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // Get the number of bytes per row for the pixel buffer
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
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);

    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];

    // Release the Quartz image
    CGImageRelease(quartzImage);

    return (image);
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
