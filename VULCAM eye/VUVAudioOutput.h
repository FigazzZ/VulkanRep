//
//  VUVAudioOutput.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 05/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VUVAudioOutput : NSObject

@property(nonatomic) AVCaptureAudioDataOutput *dataOutput;
@property(nonatomic) AVAssetWriterInput *audioWriterInput;
@property(nonatomic) BOOL isRecording;

- (instancetype)init;

- (void)setupAudioAssetWriterInput;

@end
