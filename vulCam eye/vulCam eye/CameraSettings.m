//
//  CameraSettings.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import "CameraSettings.h"
#import "CommonJSONKeys.h"
#import <UIKit/UIKit.h>

@implementation CameraSettings

@synthesize framerate;
@synthesize maxFramerate;
@synthesize shutterSpeed;
@synthesize yaw;
@synthesize pitch;
@synthesize dist;
@synthesize roll;
@synthesize exposureMode;
@synthesize autoFocusRange;
@synthesize focusMode;
@synthesize stabilizationMode;
@synthesize smoothFocusEnabled;
@synthesize wbMode;

+ (id)sharedVariables {	
    static CameraSettings *sharedVariables = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedVariables = [[self alloc] init];
    });
    return sharedVariables;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        maxFramerate = (int) [defaults integerForKey:kVVMaxFramerateKey];
        framerate = (int) [defaults integerForKey:kVVFramerateKey];
        yaw = (int) [defaults integerForKey:kVVYawKey];
        pitch = (int) [defaults integerForKey:kVVPitchKey];
        dist = (int) [defaults integerForKey:kVVDistanceKey];
        shutterSpeed = (int) [defaults integerForKey:kVVShutterSpeedKey];
        roll = 0;
        exposureMode = AVCaptureExposureModeAutoExpose;
        focusMode = AVCaptureFocusModeAutoFocus;
        smoothFocusEnabled = YES;
        focusRange = AVCaptureAutoFocusRangeRestrictionFar;
        wbMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
        stabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    return self;
}

- (NSDictionary *)getPositionJson {
    UIDeviceOrientation orient = [UIDevice currentDevice].orientation;
    NSNumber *rll = UIDeviceOrientationIsPortrait(orient) ? orient == UIDeviceOrientationPortrait ? @(-90) : @90 : @0;
    NSDictionary *pov = @{kVVDistanceKey : @(dist),
                          kVVYawKey : @(yaw),
                          kVVPitchKey : @(pitch),
                          kVVRollKey : rll};
    return pov;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:@(framerate) forKey:kVVFramerateKey];
    [defaults setValue:@(dist) forKey:kVVDistanceKey];
    [defaults setValue:@(yaw) forKey:kVVYawKey];
    [defaults setValue:@(pitch) forKey:kVVPitchKey];
    [defaults setValue:@(shutterSpeed) forKey:kVVShutterSpeedKey];
    [defaults setValue:@(maxFramerate) forKey:kVVMaxFramerateKey];
}

@end
