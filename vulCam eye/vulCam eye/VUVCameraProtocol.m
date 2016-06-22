//
//  VUVCameraProtocol.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 12.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VUVCameraProtocol.h"

@implementation VUVCameraProtocol

- (instancetype)init {
    self = [super init];
    if (self) {
        commandHandlerDelegate = self;
        messageHandler = [[MessageHandler alloc] init];
    }
    return self;
}

- (BOOL)isValueCommand:(CommandType)cType {
    switch (cType) {
        case START:
            // Fall through
        case IMPACT_START:
            // Fall through
        case IMPACT_STOP:
            // Fall through
        case VERSION:
            // Fall through
        case VIDEO_COMING:
            // Fall through
        case POSITION:
            // Fall through
        case GET_POSITION:
            // Fall through
        case CAMERA_SETTINGS:
            // Fall through
        case SET_SHUTTERSPEED:
            // Fall through
        case SET_FPS:
            // Fall through
        case VIDEODATA:
            return true;
        default:
            return false;
    }
}

@end