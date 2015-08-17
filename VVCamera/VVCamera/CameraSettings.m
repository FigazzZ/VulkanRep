//
//  CameraVariables.m
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

+ (id) sharedVariables{
    static CameraSettings *sharedVariables = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedVariables = [[self alloc] init];
    });
    return sharedVariables;
}

- (id) init{
    self = [super init];
    if(self){
        // TODO: load values from stored settings if they exist
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        framerate = [defaults floatForKey:@"framerate"];
        yaw = (int)[defaults integerForKey:@"yaw"];
        pitch = (int)[defaults integerForKey:@"pitch"];
        dist = (int)[defaults integerForKey:@"dist"];
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

- (NSDictionary *)getPositionJson{
    NSNumber *dst = [NSNumber numberWithInt: dist];
    NSNumber *yw = [NSNumber numberWithInt: yaw];
    NSNumber *ptch = [NSNumber numberWithInt: pitch];
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    NSNumber *rll;
    if(UIDeviceOrientationIsPortrait(orientation)){
        if(orientation == UIDeviceOrientationPortrait){
            rll = [NSNumber numberWithInt:-90];
        }
        else{
            rll = [NSNumber numberWithInt:90];
        }
    }
    else{
        rll = [NSNumber numberWithInt:0];
    }
    NSArray *positions = [[NSArray alloc] initWithObjects:dst, yw, ptch, rll, nil];
    NSArray *keys = [[NSArray alloc] initWithObjects:@"dist", @"yaw", @"pitch", @"roll", nil];
    NSDictionary *pov = [[NSDictionary alloc] initWithObjects:positions forKeys:keys];
    return pov;
}

@end
