//
//  VUVAudioOutput.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 05/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "VUVAudioOutput.h"
#import "VUVCamNotificationNames.h"

@interface VUVAudioOutput () <AVCaptureAudioDataOutputSampleBufferDelegate>

@property(nonatomic, strong) dispatch_queue_t audioDataQueue;

@end

@implementation VUVAudioOutput {
    BOOL finishRecording;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRecording = NO;
        finishRecording = NO;
        _audioDataQueue = dispatch_queue_create("audioDataQueue", DISPATCH_QUEUE_SERIAL);
        [self setupAudioDataOutput];
        [self setupAudioAssetWriterInput];
    }
    return self;
}

- (void)setIsRecording:(BOOL)isRecording {
    _isRecording = isRecording;
    finishRecording = !isRecording;
}

- (void)setupAudioDataOutput {
    _dataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [_dataOutput setSampleBufferDelegate:self queue:_audioDataQueue];

}

- (void)setupAudioAssetWriterInput {
    AudioChannelLayout stereoChannelLayout = {
            .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
            .mChannelBitmap = 0,
            .mNumberChannelDescriptions = 0
    };

    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];

    // Get the compression settings for 128 kbps AAC.
    NSDictionary *compressionAudioSettings = @{
            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
            AVEncoderBitRateKey : @128000,
            AVSampleRateKey : @44100,
            AVChannelLayoutKey : channelLayoutAsData,
            AVNumberOfChannelsKey : @2
    };

    // Create the asset writer input with the compression settings and specify the media type as audio.
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:compressionAudioSettings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
}

#pragma mark delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_isRecording && _audioWriterInput.readyForMoreMediaData) {
        if (!CMSampleBufferDataIsReady(sampleBuffer)) {
            return;
        }
        if (![_audioWriterInput appendSampleBuffer:sampleBuffer]) {
            NSLog(@"writing audio failed");
        }

    }
    else if (!_isRecording && finishRecording) {
        finishRecording = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishRecording object:self];
    }

}


@end
