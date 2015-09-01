//
//  StreamServer.h
//  VVCamera
//
//  Created by Bitwise on 18/08/15.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#ifndef VVCamera_StreamServer_h
#define VVCamera_StreamServer_h
#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

#define BOUNDARY @"boundary"

@interface StreamServer : NSObject

@property (strong) GCDAsyncSocket *connectedSocket;
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic) BOOL isRunning;

- (void)startAcceptingConnections;
- (void)stopAcceptingConnections;

@end

#endif
