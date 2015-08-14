//
//  CameraVariables.h
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraVariables : NSObject{
    float framerate;
    int yaw;
    int dist;
    int pitch;
    int roll;
}

+ (id) sharedVariables;

@property (nonatomic) float framerate;
@property (nonatomic) int yaw;
@property (nonatomic) int pitch;
@property (nonatomic) int dist;
@property (nonatomic) int roll;
// TODO: Add white balance etc.

- (NSDictionary *)getPositionJson;

@end
