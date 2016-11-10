//
//  VUVAVCaptureManager.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VUVStreamServer.h"
#import "VUVVideoTrimmer.h"

typedef NS_ENUM(NSInteger, CameraState) {
    AIM_MODE,
    CAMERA_MODE
};

typedef NS_ENUM(NSInteger, RecordingMode) {
    STANDARD,
    IMPACT
};

@interface VUVAVCaptureManager : NSObject

@property(NS_NONATOMIC_IOSONLY, getter=isRecording, readonly) BOOL isRecording;
@property(NS_NONATOMIC_IOSONLY, getter=isStreaming, readonly) BOOL isStreaming;
@property(nonatomic, setter=setStreamServer:, weak) VUVStreamServer *streamServer;
@property(nonatomic) NSTimeInterval impactTime;
@property(nonatomic) NSTimeInterval impactStart;
@property(nonatomic) NSTimeInterval impactEnd;
@property(nonatomic) NSNumber *frameCount;
@property(nonatomic) NSNumber *framerate;
@property(nonatomic) float timeBefore;
@property(nonatomic) float timeAfter;

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

- (void)startAssetWriter;

- (void)startRecording:(RecordingMode)mode;

- (void)stopRecording;

- (void)startCaptureSession;

- (void)stopCaptureSession;

+ (void)deleteVideo:(NSURL *)file;

+ (NSURL *)generateFilePath;

@end
