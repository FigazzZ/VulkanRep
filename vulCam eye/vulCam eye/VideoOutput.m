//
//  VideoOutput.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 05/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "VideoOutput.h"
#import "ImageUtility.h"
#import "CameraSettings.h"
#import "CamNotificationNames.h"


static const CGSize kQVStreamSize = (CGSize) {
        .width = 320,
        .height = 180
};

@interface VideoOutput () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, strong) dispatch_queue_t videoDataQueue;
@property(nonatomic, strong) dispatch_queue_t streamQueue;

@end

@implementation VideoOutput {
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
    BOOL finishRecording;
    int64_t frameNumber;
    int32_t streamFrame;
    int32_t streamFrameSkip;
}

- (instancetype)initWithInput:(AVCaptureDeviceInput *)input {
    self = [super init];
    if (self) {
        _isStreaming = NO;
        finishRecording = NO;
        _isRecording = NO;
        _videoDataQueue = dispatch_queue_create("videoDataQueue", DISPATCH_QUEUE_SERIAL);
        _streamQueue = dispatch_queue_create("streamQueue", DISPATCH_QUEUE_SERIAL);
        [self setupVideoDataOutput:input];
        [self setupVideoAssetWriterInput];
    }
    return self;
}

- (void)setVideoFPS:(int32_t)videoFPS {
    _videoFPS = videoFPS;
    streamFrameSkip = videoFPS / 10;
}


- (void)setIsRecording:(BOOL)isRecording {
    if (isRecording) {
        frameNumber = 0;
    }
    _isRecording = isRecording;
    finishRecording = !isRecording;
}

- (void)setupVideoDataOutput:(AVCaptureDeviceInput *)input {
    _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _dataOutput.videoSettings = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [_dataOutput setSampleBufferDelegate:self queue:_videoDataQueue];
    [_dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    _connection = [self createVideoConnectionForOutput:_dataOutput andInput:input];
}


- (AVCaptureConnection *)createVideoConnectionForOutput:(AVCaptureOutput *)output andInput:(AVCaptureDeviceInput *)videoIn {
    AVCaptureConnection *connection = [[AVCaptureConnection alloc] initWithInputPorts:videoIn.ports output:output];
    [VideoOutput configureVideoConnection:connection];
    return connection;
}

+ (void)configureVideoConnection:(AVCaptureConnection *)connection {
    if (connection.supportsVideoOrientation) {
        AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
        connection.videoOrientation = orientation;
    }
    if (connection.supportsVideoStabilization) {
        connection.preferredVideoStabilizationMode = [[CameraSettings sharedVariables] stabilizationMode];
    }
}

- (void)setupVideoAssetWriterInput {
    NSDictionary *settings = @{
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoHeightKey : @720,
            AVVideoWidthKey : @1280
    };
    _videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:settings];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary *pxlBufAttrs = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:_videoWriterInput
                                                                    sourcePixelBufferAttributes:pxlBufAttrs];
}

#pragma mark streaming

- (void)startStreaming {
    streamFrame = 0;
    NSLog(@"Streaming started");
    _isStreaming = YES;
}

- (void)stopStreaming {
    _isStreaming = NO;
    NSLog(@"Streaming stopped");
}

#pragma mark delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (_isRecording && _videoWriterInput.readyForMoreMediaData) {
        if ([pixelBufferAdaptor appendPixelBuffer:imageBuffer withPresentationTime:CMTimeMake(frameNumber, _videoFPS)]) {
            frameNumber++;
        }
        else {
            NSLog(@"writing video failed");
        }
    }
    else if (!_isRecording && finishRecording) {
        finishRecording = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishRecording object:self];
    }

    if (_isStreaming) {
        streamFrame++;
        if (streamFrame == streamFrameSkip) {
            CVImageBufferRef buf = (CVImageBufferRef) CFRetain(imageBuffer);
            dispatch_async(_streamQueue, ^(void) {
                UIImage *image = [ImageUtility imageFromSampleBuffer:buf];

                NSTimeInterval timestamp = [NSDate date].timeIntervalSince1970;
                image = [ImageUtility scaleImage:image toSize:kQVStreamSize];
                [_streamServer writeImageToSocket:image withTimestamp:timestamp];
                CFRelease(buf);
            });
            streamFrame = 0;
        }

    }
}


@end
