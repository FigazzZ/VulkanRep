//
//  CameraSettings.m
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "CameraSettings.h"
#import <UIKit/UIKit.h>

@implementation CameraSettings

@synthesize framerate;
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
        framerate = [defaults floatForKey:@"framerate"];
        yaw = (int) [defaults integerForKey:@"yaw"];
        pitch = (int) [defaults integerForKey:@"pitch"];
        dist = (int) [defaults integerForKey:@"dist"];
        roll = 0;
        NSLog(@"fps: %f", framerate);
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
    NSNumber *dst = @(dist);
    NSNumber *yw = @(yaw);
    NSNumber *ptch = @(pitch);
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    NSNumber *rll;
    if (UIDeviceOrientationIsPortrait(orientation)) {
        if (orientation == UIDeviceOrientationPortrait) {
            rll = @(-90);
        }
        else {
            rll = @90;
        }
    }
    else {
        rll = @0;
    }
    NSArray *positions = @[dst, yw, ptch, rll];
    NSArray *keys = @[@"dist", @"yaw", @"pitch", @"roll"];
    NSDictionary *pov = @{keys : positions};
    return pov;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:@(framerate) forKey:@"framerate"];
    [defaults setValue:@(dist) forKey:@"dist"];
    [defaults setValue:@(yaw) forKey:@"yaw"];
    [defaults setValue:@(pitch) forKey:@"pitch"];
}

@end
