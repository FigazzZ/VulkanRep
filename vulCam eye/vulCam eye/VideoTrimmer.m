//
//  VideoTrimmer.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 26/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "VideoTrimmer.h"
#import "AVCaptureManager.h"
#import "CamNotificationNames.h"

@implementation VideoTrimmer

+ (BOOL)trimVideoAtURL:(NSURL *)videoURL
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
        NSURL *fileURL = [AVCaptureManager generateFilePath];
        exportSession.outputURL = fileURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.timeRange = range;

        [exportSession exportAsynchronouslyWithCompletionHandler:^{

            if (AVAssetExportSessionStatusCompleted == exportSession.status) {
                NSLog(@"AVAssetExportSessionStatusCompleted");
                [[NSNotificationCenter defaultCenter] postNotificationName:kNNFinishTrimming object:fileURL];
            } else if (AVAssetExportSessionStatusFailed == exportSession.status) {
                // a failure may happen because of an event out of your control
                // for example, an interruption like a phone call comming in
                // make sure and handle this case appropriately
                NSLog(@"AVAssetExportSessionStatusFailed");
            } else {
                NSLog(@"Export Session Status: %ld", (long)exportSession.status);
            }
        }];
    }

    return success;
}

+ (CMTimeRange)calculateTimeRange:(const CMTime *)impactTime
                        timeAfter:(const float *)timeAfter
                       timeBefore:(const float *)timeBefore
                         duration:(const CMTime *)duration {
    Float64 secs = CMTimeGetSeconds(*impactTime) - *timeBefore;
    CMTime startDiff = secs > 0.0 ? CMTimeMakeWithSeconds(secs, NSEC_PER_SEC) : kCMTimeZero;
    CMTime endDiff = CMTimeMinimum(CMTimeAdd(*impactTime, CMTimeMakeWithSeconds(*timeAfter, NSEC_PER_SEC)), *duration);
    CMTimeRange range = CMTimeRangeFromTimeToTime(startDiff, endDiff);
    NSLog(@"Time Range: %@", [NSValue valueWithCMTimeRange:range]);
    return range;
}


@end
