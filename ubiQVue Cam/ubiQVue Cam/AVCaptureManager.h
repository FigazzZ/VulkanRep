//
//  AVCaptureManager.h
//  VVCamera
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "StreamServer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    AIM_MODE,
    CAMERA_MODE
} CameraState;


@interface AVCaptureManager : NSObject

@property(nonatomic, readonly) BOOL isRecording;
@property(nonatomic, readonly) BOOL isStreaming;
@property(nonatomic, weak) StreamServer *streamServer;

- (id)initWithPreviewView:(UIView *)previewView;

- (void)setCameraSettings;

- (void)resetFormat;

- (NSURL *)getVideoFile;

- (void)addPreview:(UIView *)previewView;

- (void)removePreview;

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;

- (void)prepareAssetWriter;

- (void)closeAssetWriter;

- (void)startRecording;

- (void)stopRecording;

+ (void)deleteVideo:(NSURL *)file;

@end
