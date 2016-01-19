//
//  VideoOutput.h
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 05/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "StreamServer.h"

@interface VideoOutput : NSObject

@property(nonatomic) AVCaptureVideoDataOutput *dataOutput;
@property(nonatomic) AVCaptureConnection *connection;
@property(nonatomic) AVAssetWriterInput *videoWriterInput;
@property(nonatomic) int32_t videoFPS;
@property(nonatomic) BOOL isRecording;
@property(nonatomic) BOOL isStreaming;
@property(nonatomic, weak) StreamServer *streamServer;

- (instancetype)initWithInput:(AVCaptureDeviceInput *)input;

- (void)startStreaming;

- (void)stopStreaming;

- (void)setupVideoAssetWriterInput;

+ (void)configureVideoConnection:(AVCaptureConnection *)connection;

@end
