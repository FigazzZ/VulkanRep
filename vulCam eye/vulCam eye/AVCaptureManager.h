//
//  AVCaptureManager.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "StreamServer.h"
#import "VideoTrimmer.h"

typedef NS_ENUM(NSInteger, CameraState) {
    AIM_MODE,
    CAMERA_MODE
};

typedef NS_ENUM(NSInteger, RecordingMode) {
    NORMAL,
    IMPACT
};

@interface AVCaptureManager : NSObject

@property(NS_NONATOMIC_IOSONLY, getter=isRecording, readonly) BOOL isRecording;
@property(NS_NONATOMIC_IOSONLY, getter=isStreaming, readonly) BOOL isStreaming;
@property(NS_NONATOMIC_IOSONLY, getter=getVideoFile, readonly, copy) NSURL *videoFile;
@property(nonatomic, setter=setStreamServer:, weak) StreamServer *streamServer;
@property(nonatomic) VideoTrimmer *videoTrimmer;
@property(nonatomic) RecordingMode recordingMode;
@property(nonatomic) CMTime impactTime;
@property(nonatomic) NSInteger timeBefore;
@property(nonatomic) NSInteger timeAfter;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPreviewView:(UIView *)previewView NS_DESIGNATED_INITIALIZER;

- (void)setCameraSettings:(CGPoint)point;

- (void)resetFormat;

- (void)addPreview:(UIView *)previewView;

- (void)removePreview;

- (void)setShutterSpeed;

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;

- (void)prepareAssetWriter;

- (void)closeAssetWriter;

- (void)startRecording;

- (void)stopRecording;

- (void)startCaptureSession;

- (void)stopCaptureSession;

+ (void)deleteVideo:(NSURL *)file;

+ (NSURL *)generateFilePath;

@end
