//
//  CameraProtocol.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 12.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CameraProtocol.h"

@implementation CameraProtocol

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
        case VERSION:
            // Fall through
        case VALUE:
            // Fall through
        case VIDEO_COMING:
            // Fall through
        case POSITION:
            // Fall through
        case GET_POSITION:
            // Fall through
        case CAMERA_SETTINGS:
            // Fall through
        case VIDEODATA:
            return true;
        default:
            return false;
    }
}

@end