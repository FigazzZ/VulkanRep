//
//  CameraMessageHandler.m
//  VVCamera
//
//  Created by Käyttäjä on 12.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common/Command.h"
#import "Common/MessageHandler.h"

@interface CameraMessageHandler : MessageHandler

@end

@implementation CameraMessageHandler

+ (void)handleMessage:(Command *)command
{
    NSDictionary *cmd = [NSDictionary dictionaryWithObject:command forKey:@"command"];
    // TODO: Handle properly
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendNotificationWithCommand:cmd name:@"ProtocolNotification"];
    });
}

@end
