//
//  VUVVideoTrimmer.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 26/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "VUVVideoTrimmer.h"
#import "VUVAVCaptureManager.h"
#import "VUVCamNotificationNames.h"
#import "FileLogger.h"

@implementation VUVVideoTrimmer


+ (void)trimImpactVideoAtURL:(NSURL *)sourceURL
              withFrameCount:(NSNumber *)frameCount
                   framerate:(NSNumber *)framerate
                 impactStart:(NSTimeInterval)impactStart
                  impactTime:(NSTimeInterval)impactTime
                   impactEnd:(NSTimeInterval)impactEnd
                  timeBefore:(float)timeBefore
                   timeAfter:(float)timeAfter
{
    dispatch_queue_t trimmingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    NSURL *destinationURL = [VUVAVCaptureManager generateFilePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL
                                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)}];
    __block AVAssetReader *videoReader;
    NSNumber *impactFrame = @([frameCount intValue]*((impactTime-impactStart)/(impactEnd-impactStart)));
    NSNumber *framesBefore = @([framerate intValue]*timeBefore);
    NSNumber *framesAfter = @([framerate intValue]*timeAfter);

    __block NSNumber *startingFrame = @([impactFrame intValue]-[framesBefore intValue]);
    __block NSNumber *endingFrame = @([impactFrame intValue]+[framesAfter intValue]);

    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:
            ^{
                dispatch_async(trimmingQueue,
                        ^{
                            AVAssetTrack *videoTrack = nil;
                            NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                            if ([tracks count] == 1) {
                                videoTrack = tracks[0];
                                NSError *error = nil;

                                videoReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
                                if (error)
                                    [FileLogger printAndLogToFile:[NSString stringWithFormat:@"%@", error.localizedDescription]];

                                NSString *key = (NSString *) kCVPixelBufferPixelFormatTypeKey;
                                NSNumber *value = @(kCVPixelFormatType_32BGRA);
                                NSDictionary *videoSettings = @{key: value};
                                [videoReader addOutput:[AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:videoSettings]];

                                [VUVVideoTrimmer readFrames:videoReader
                                          withStartingFrame:startingFrame
                                                endingFrame:endingFrame
                                               andFramerate:framerate
                                           toDestinationURL:destinationURL];
                            }
                        });
            }];
}

+(void)readFrames:(AVAssetReader *)videoReader
withStartingFrame:(NSNumber *)startingFrame
      endingFrame:(NSNumber *)endingFrame
     andFramerate:(NSNumber *)framerate
 toDestinationURL:(NSURL *)destinationURL
{
    [videoReader startReading];

    if ([startingFrame integerValue] < 0)
    {
        startingFrame = @0;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNTooShortImpactVid object:nil];
        [FileLogger printAndLogToFile:@"Not enough buffer in impact video"];
    }

    NSError *err;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:destinationURL fileType:AVFileTypeMPEG4 error:&err];

    NSDictionary *settings = @{
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoHeightKey : @720,
            AVVideoWidthKey : @1280
    };
    AVAssetWriterInput *videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:settings];

    // Using these settings instead of the ones above results in an empty video. Apparently the output has to be re-encoded
    /*
    CMFormatDescriptionRef formatDescription;
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 1280, 720, nil, &formatDescription);
    AVAssetWriterInput *videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil sourceFormatHint:formatDescription];
    */

    videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary *pxlBufAttrs = @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:videoWriterInput
                                                                                                          sourcePixelBufferAttributes:pxlBufAttrs];

    if ([videoWriter canAddInput:videoWriterInput])
    {
        [videoWriter addInput:videoWriterInput];
    }
    else
    {
        [FileLogger printAndLogToFile:[NSString stringWithFormat:@"%@", err.localizedDescription]];
        [VUVVideoTrimmer postStatusNotification:videoReader.status andDestinationURL:destinationURL];
        return;
    }

    if (videoReader.outputs.count < 1)
    {
        [FileLogger printAndLogToFile:@"VideoReader outputs are 0!"];
        [VUVVideoTrimmer postStatusNotification:AVAssetReaderStatusFailed andDestinationURL:destinationURL];
        return;
    }

    NSUInteger currentFrame = 0;
    AVAssetReaderTrackOutput * output = (AVAssetReaderTrackOutput *) [videoReader.outputs objectAtIndex:0];

    if (videoWriter.status != AVAssetWriterStatusWriting)
    {
        [videoWriter startWriting];
        [videoWriter startSessionAtSourceTime:kCMTimeZero];
    }

    while (videoReader.status == AVAssetReaderStatusReading && videoWriter.status == AVAssetWriterStatusWriting)
    {
        if (videoWriterInput.readyForMoreMediaData)
        {
            CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
            if (sampleBuffer)
            {
                CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

                if (currentFrame >= [startingFrame integerValue] && currentFrame <= [endingFrame integerValue])
                {
                    CMTime presentationTime = CMTimeMake(currentFrame - [startingFrame integerValue], [framerate intValue]);

                    if (![pixelBufferAdaptor appendPixelBuffer:imageBuffer
                                          withPresentationTime:presentationTime])
                    {
                        [FileLogger printAndLogToFile:[NSString stringWithFormat:@"Rewriting video failed"]];
                    }
                }

                // Here the frames can be processed at some point in the future, if the need arises
//            // Lock the image buffer
//            CVPixelBufferLockBaseAddress(imageBuffer,0);
//            // Get information of the image
//            uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
//            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
//            size_t width = CVPixelBufferGetWidth(imageBuffer);
//            size_t height = CVPixelBufferGetHeight(imageBuffer);
                //
                // Here's where you can process the buffer!
                // (your code goes here)
                // Finish processing the buffer!
                // Unlock the image buffer
                // CVPixelBufferUnlockBaseAddress(imageBuffer,0);


                // sampleBuffer has to be released to free up memory
                CFRelease(sampleBuffer);
            }
            currentFrame++;
        }
    }

    [videoWriter finishWritingWithCompletionHandler:^{
        [VUVVideoTrimmer postStatusNotification:videoReader.status andDestinationURL:destinationURL];
    }];
}

+ (void)postStatusNotification:(AVAssetReaderStatus)status andDestinationURL:(NSURL *)destinationURL
{
    if (status == AVAssetReaderStatusCompleted)
    {
        [FileLogger printAndLogToFile:[NSString stringWithFormat:@"AVAssetExportSessionStatusCompleted"]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishTrimming object:destinationURL];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNRecordingFailed object:nil];
        [FileLogger printAndLogToFile:[NSString stringWithFormat:@"Export Session Status: %ld", (long) status]];
        [VUVAVCaptureManager deleteVideo:destinationURL];
    }
}


+ (void)exportVideoWithExportSession:(AVAssetExportSession *)exportSession
                           withRange:(CMTimeRange)range
{
    NSURL *fileURL = [VUVAVCaptureManager generateFilePath];
    exportSession.outputURL = fileURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.timeRange = range;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{

        if (AVAssetExportSessionStatusCompleted == exportSession.status)
        {
            [FileLogger printAndLogToFile:[NSString stringWithFormat:@"AVAssetExportSessionStatusCompleted"]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishTrimming object:fileURL];
        }
        else if (AVAssetExportSessionStatusFailed == exportSession.status)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNRecordingFailed object:nil];
            [FileLogger printAndLogToFile:[NSString stringWithFormat:@"AVAssetExportSessionStatusFailed"]];
            [VUVAVCaptureManager deleteVideo:fileURL];
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNRecordingFailed object:nil];
            [FileLogger printAndLogToFile:[NSString stringWithFormat:@"Export Session Status: %ld", (long) exportSession.status]];
            [VUVAVCaptureManager deleteVideo:fileURL];
        }
    }];
}


+ (CMTimeRange)calculateTimeRange:(const CMTime *)impactTime
                        timeAfter:(const float *)timeAfter
                       timeBefore:(const float *)timeBefore
                         duration:(const CMTime *)duration {
    Float64 secs = CMTimeGetSeconds(*impactTime) - *timeBefore;
    CMTime startDiff = secs > 0.0 ? CMTimeMakeWithSeconds(secs, NSEC_PER_SEC) : kCMTimeZero;
    if(secs < 0.0){
        [[NSNotificationCenter defaultCenter] postNotificationName:kNNTooShortImpactVid object:nil];
    }
    CMTime endDiff = CMTimeMinimum(CMTimeAdd(*impactTime, CMTimeMakeWithSeconds(*timeAfter, NSEC_PER_SEC)), *duration);
    CMTimeRange range = CMTimeRangeFromTimeToTime(startDiff, endDiff);
    [FileLogger printAndLogToFile:[NSString stringWithFormat:@"Time Range: %@", [NSValue valueWithCMTimeRange:range]]];
    return range;
}


@end
