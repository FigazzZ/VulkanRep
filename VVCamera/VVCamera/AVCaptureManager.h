//
//  AVCaptureManager.h
//  VVCamera
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#ifndef VVCamera_AVCaptureManager_h
#define VVCamera_AVCaptureManager_h
#import "StreamServer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    AIM_MODE,
    CAMERA_MODE
} CameraState;


@interface AVCaptureManager : NSObject

@property (nonatomic, readonly) BOOL isRecording;
@property (nonatomic, weak) StreamServer *streamServer;

- (id)initWithPreviewView:(UIView *)previewView;
- (void)setCameraSettings;
- (void)resetFormat;
- (void)captureImage;
- (NSURL *)getVideoFile;
- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;
- (void)startRecording;
- (void)stopRecording;

@end

#endif