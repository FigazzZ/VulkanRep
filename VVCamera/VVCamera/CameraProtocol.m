//
//  CameraProtocol.m
//  VVCamera
//
//  Created by Käyttäjä on 12.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common/VVProtocol.h"
#import "Common/CommandType.h"

@interface CameraProtocol : VVProtocol<CommandHandlingDelegate>

@end

@implementation CameraProtocol

- (id) init{
    self = [super init];
    if(self){
        commandHandlerDelegate = self;
    }
    return self;
}

- (BOOL) isValueCommand:(CommandType)cType{
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