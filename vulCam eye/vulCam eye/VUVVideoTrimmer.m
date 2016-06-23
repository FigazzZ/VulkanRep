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

@implementation VUVVideoTrimmer


+ (BOOL)trimImpactVideoAtURL:(NSURL *)videoURL
              withImpactTime:(CMTime)impactTime
                   timeAfter:(float)timeAfter
                  timeBefore:(float)timeBefore {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL
                                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @(YES)}];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    BOOL success = exportSession != nil;

    if (success) {
        CMTime duration = CMTimeMakeWithSeconds(CMTimeGetSeconds(asset.duration), NSEC_PER_SEC);
        CMTimeRange range = [self calculateTimeRange:&impactTime timeAfter:&timeAfter timeBefore:&timeBefore duration:&duration];

        [self exportVideoWithExportSession:exportSession withRange:range];
    }

    return success;
}

+ (BOOL)trimVideoBeginningAtUrl:(NSURL *)videoURL withSecondsToTrim:(NSTimeInterval)secondsToTrim {

    if (secondsToTrim < 0)
    {
        // TODO: handle too short videos
        return YES;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL
                                            options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @(YES)}];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    BOOL success = exportSession != nil;

    if (success)
    {
        CMTime duration = CMTimeMakeWithSeconds(CMTimeGetSeconds(asset.duration), NSEC_PER_SEC);
        CMTime actualStart = CMTimeMakeWithSeconds(secondsToTrim, NSEC_PER_SEC);
        CMTimeRange range = CMTimeRangeFromTimeToTime(actualStart, duration);

        [self exportVideoWithExportSession:exportSession withRange:range];
    }

    return success;
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
            NSLog(@"AVAssetExportSessionStatusCompleted");
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishTrimming object:fileURL];
        }
        else if (AVAssetExportSessionStatusFailed == exportSession.status)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNRecordingFailed object:nil];
            NSLog(@"AVAssetExportSessionStatusFailed");
            [VUVAVCaptureManager deleteVideo:fileURL];
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNNRecordingFailed object:nil];
            NSLog(@"Export Session Status: %ld", (long) exportSession.status);
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
    NSLog(@"Time Range: %@", [NSValue valueWithCMTimeRange:range]);
    return range;
}


@end
