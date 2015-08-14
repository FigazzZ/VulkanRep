//
//  CameraVariables.m
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "CameraVariables.h"

@implementation CameraVariables

@synthesize framerate;
@synthesize yaw;
@synthesize pitch;
@synthesize dist;
@synthesize roll;

+ (id) sharedVariables{
    static CameraVariables *sharedVariables = nil;
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
        framerate = 120.0;
        yaw = 0;
        pitch = 0;
        dist = 10;
        roll = 0;
    }
    return self;
}

- (NSDictionary *)getPositionJson{
    NSNumber *dst = [NSNumber numberWithInt: dist];
    NSNumber *yw = [NSNumber numberWithInt: yaw];
    NSNumber *ptch = [NSNumber numberWithInt: pitch];
    NSNumber *rll = [NSNumber numberWithInt: roll];
    NSArray *positions = [[NSArray alloc] initWithObjects:dst, yw, ptch, rll, nil];
    NSArray *keys = [[NSArray alloc] initWithObjects:@"dist", @"yaw", @"pitch", @"roll", nil];
    NSDictionary *pov = [[NSDictionary alloc] initWithObjects:positions forKeys:keys];
    return pov;
}

@end
