//
//  CameraSettings.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import "CameraSettings.h"
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
        // TODO: load values from stored settings if they exist
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        maxFramerate = 240.0;
        framerate = (int)[defaults integerForKey:@"framerate"];
        yaw = (int) [defaults integerForKey:@"yaw"];
        pitch = (int) [defaults integerForKey:@"pitch"];
        dist = (int) [defaults integerForKey:@"dist"];
        shutterSpeed = (int) [defaults integerForKey:@"shutterSpeed"];
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
    NSDictionary *pov = @{@"dist" : @(dist), @"yaw" : @(yaw), @"pitch" : @(pitch), @"roll" : rll};
    return pov;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:@(framerate) forKey:@"framerate"];
    [defaults setValue:@(dist) forKey:@"dist"];
    [defaults setValue:@(yaw) forKey:@"yaw"];
    [defaults setValue:@(pitch) forKey:@"pitch"];
    [defaults setValue:@(shutterSpeed) forKey:@"shutterSpeed"];
}

@end
