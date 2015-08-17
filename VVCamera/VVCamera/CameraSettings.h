//
//  CameraVariables.h
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraSettings : NSObject{
    float framerate;
    int yaw;
    int dist;
    int pitch;
    int roll;
    AVCaptureExposureMode exposureMode;
    AVCaptureFocusMode focusMode;
    AVCaptureVideoStabilizationMode stabilizationMode;
    AVCaptureWhiteBalanceMode wbMode;
    AVCaptureAutoFocusRangeRestriction focusRange;
    BOOL smoothFocusEnabled;
}

+ (id) sharedVariables;

@property (nonatomic) float framerate;
@property (nonatomic) int yaw;
@property (nonatomic) int pitch;
@property (nonatomic) int dist;
@property (nonatomic) int roll;
@property (nonatomic) AVCaptureExposureMode exposureMode;
@property (nonatomic) AVCaptureFocusMode focusMode;
@property (nonatomic) AVCaptureVideoStabilizationMode stabilizationMode;
@property (nonatomic) AVCaptureWhiteBalanceMode wbMode;
@property (nonatomic) AVCaptureAutoFocusRangeRestriction autoFocusRange;
@property (nonatomic) BOOL smoothFocusEnabled;

- (NSDictionary *)getPositionJson;

@end
