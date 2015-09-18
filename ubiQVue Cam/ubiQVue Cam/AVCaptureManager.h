//
//  AVCaptureManager.h
//  VVCamera
//
//  Created by Juuso Kaitila on 23.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "StreamServer.h"

typedef NS_ENUM(unsigned int, CameraState) {
    AIM_MODE,
    CAMERA_MODE
};


@interface AVCaptureManager : NSObject

@property(nonatomic, readonly) BOOL isRecording;
@property(nonatomic, readonly) BOOL isStreaming;
@property(nonatomic, weak) StreamServer *streamServer;

- (instancetype)initWithPreviewView:(UIView *)previewView NS_DESIGNATED_INITIALIZER;

- (void)setCameraSettings;

- (void)resetFormat;

@property (NS_NONATOMIC_IOSONLY, getter=getVideoFile, readonly, copy) NSURL *videoFile;

- (void)addPreview:(UIView *)previewView;

- (void)removePreview;

- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;

- (void)prepareAssetWriter;

- (void)closeAssetWriter;

- (void)startRecording;

- (void)stopRecording;

+ (void)deleteVideo:(NSURL *)file;

@end
