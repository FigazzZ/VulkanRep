//
//  VideoTrimmer.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 26/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "VideoTrimmer.h"
#import "AVCaptureManager.h"

@implementation VideoTrimmer {
    AVAssetWriterInput *writerInput;
    AVAssetWriterInputPixelBufferAdaptor *pixelBufAdaptor;
    AVAssetReader *reader;
    AVAssetWriter *writer;
    AVAssetReaderOutput *readerOutput;
}

- (BOOL)trimVideoAtURL:(NSURL *)videoURL atRange:(CMTimeRange)range {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL
                                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @(YES)}];
    BOOL success = [self createAssetReader:asset withTimeRange:range];
    if (success) {
        success = [self createAssetWriter];
    }

    if (success) {
        [reader startReading];
        [writer startWriting];
        [writer startSessionAtSourceTime:kCMTimeZero];
        dispatch_queue_t encodeQueue = dispatch_queue_create("Encode Queue", NULL);
        [writerInput requestMediaDataWhenReadyOnQueue:encodeQueue usingBlock:^{
            while ([writerInput isReadyForMoreMediaData]) {
                CMSampleBufferRef sampleBuf = [readerOutput copyNextSampleBuffer];
                if (sampleBuf != NULL) {
                    BOOL success = [writerInput appendSampleBuffer:sampleBuf];
                    CFRelease(sampleBuf);
                    if (!success && writer.status == AVAssetWriterStatusFailed) {
                        NSError *fail = writer.error;
                        NSLog(@"%@", fail.localizedDescription);
                    }
                } else {
                    if (reader.status == AVAssetReaderStatusFailed) {
                        NSError *fail = reader.error;
                        NSLog(@"%@", fail.localizedDescription);
                    } else {
                        [writerInput markAsFinished];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [writer finishWritingWithCompletionHandler:^{
                                //handle completion
                            }];
                        });
                        break;
                    }
                }
            }
        }];
    }

    return success;
}

- (BOOL)createAssetReader:(AVAsset *)asset withTimeRange:(CMTimeRange)range {
    NSError *error;
    reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    BOOL success = reader != nil;
    if (success) {
        AVAsset *localAsset = reader.asset;
        reader.timeRange = range;
        AVAssetTrack *videoTrack = [localAsset tracksWithMediaType:AVMediaTypeVideo][0];
        readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:nil];
        if ([reader canAddOutput:readerOutput]) {
            [reader addOutput:readerOutput];
        } else {
            success = NO;
        }
    }

    return success;
}

- (BOOL)createAssetWriter {
    _fileURL = [AVCaptureManager generateFilePath];
    NSError *err;
    writer = [AVAssetWriter assetWriterWithURL:_fileURL fileType:AVFileTypeMPEG4 error:&err];
    BOOL success = writer != nil;
    if (success) {
        writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil];
//        NSDictionary *pxlBufAttrs = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
//        pixelBufAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput
//                                                                     sourcePixelBufferAttributes:pxlBufAttrs];
        if ([writer canAddInput:writerInput]) {
            [writer addInput:writerInput];
        } else {
            success = NO;
        }
    }

    return success;
}

@end
