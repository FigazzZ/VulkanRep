//
//  VUVStreamServer.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 18/08/15.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GCDAsyncSocket.h>

extern NSString *const kQVStreamBoundary;

@interface VUVStreamServer : NSObject

@property(strong) GCDAsyncSocket *connectedSocket;
@property(nonatomic, strong) GCDAsyncSocket *serverSocket;
@property(nonatomic) BOOL isRunning;

- (void)startAcceptingConnections;

- (void)stopAcceptingConnections;

- (void)writeImageToSocket:(UIImage *)image withTimestamp:(NSTimeInterval)timestamp;

@end

