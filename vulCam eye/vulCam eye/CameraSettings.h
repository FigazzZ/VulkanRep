//
//  CameraSettings.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraSettings : NSObject {
    float framerate;
    int yaw;
    double dist;
    int pitch;
    int roll;
    float maxFramerate;
    int shutterSpeed;
    AVCaptureExposureMode exposureMode;
    AVCaptureFocusMode focusMode;
    AVCaptureVideoStabilizationMode stabilizationMode;
    AVCaptureWhiteBalanceMode wbMode;
    AVCaptureAutoFocusRangeRestriction focusRange;
    BOOL smoothFocusEnabled;
}

+ (id)sharedVariables;

@property(nonatomic) float framerate;
@property(nonatomic) float maxFramerate;
@property(nonatomic) int shutterSpeed;
@property(nonatomic) int yaw;
@property(nonatomic) int pitch;
@property(nonatomic) double dist;
@property(nonatomic) int roll;
@property(nonatomic) AVCaptureExposureMode exposureMode;
@property(nonatomic) AVCaptureFocusMode focusMode;
@property(nonatomic) AVCaptureVideoStabilizationMode stabilizationMode;
@property(nonatomic) AVCaptureWhiteBalanceMode wbMode;
@property(nonatomic) AVCaptureAutoFocusRangeRestriction autoFocusRange;
@property(nonatomic) BOOL smoothFocusEnabled;

@property(NS_NONATOMIC_IOSONLY, getter=getPositionJson, readonly, copy) NSDictionary *positionJson;

- (void)saveSettings;

@end
