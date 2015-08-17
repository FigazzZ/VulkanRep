//
//  AVCaptureManager.h
//  SlowMotionVideoRecorder
//  https://github.com/shu223/SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "StreamDelegate.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@protocol AVCaptureManagerDelegate <NSObject>
- (void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                                      error:(NSError *)error;
@end

@interface AVCaptureManager : NSObject

@property (nonatomic, assign) id<AVCaptureManagerDelegate> delegate;
@property (nonatomic) StreamDelegate *streamDelegate;
@property (nonatomic, readonly) BOOL isRecording;

- (id)initWithPreviewView:(UIView *)previewView;
- (void)setCameraSettings;
- (void)setPreviewFrame:(CGRect)frame;
- (void)resetFormat;
- (NSURL *)getVideoFile;
- (BOOL)switchFormatWithDesiredFPS:(CGFloat)desiredFPS;
- (void)startRecording;
- (void)stopRecording;

@end
