//
//  AVCaptureManager.h
//  SlowMotionVideoRecorder
//  https://github.com/shu223/SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#ifndef VVCamera_AVCaptureManager_h
#define VVCamera_AVCaptureManager_h
#import "StreamServer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface AVCaptureManager : NSObject

@property (nonatomic, readonly) BOOL isRecording;
@property (nonatomic, weak) StreamServer *streamServer;

- (id)initWithPreviewView:(UIView *)previewView;
- (void)setCameraSettings;
- (void)setPreviewFrame:(CGRect)frame;
- (void)resetFormat;
- (void)captureImage;
- (NSURL *)getVideoFile;
- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;
- (void)startRecording;
- (void)stopRecording;

@end

#endif