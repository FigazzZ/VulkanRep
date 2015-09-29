//
//  StreamServer.h
//  ubiQVue Cam
//
//  Created by Bitwise on 18/08/15.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

extern NSString *const kQVStreamBoundary;

@interface StreamServer : NSObject

@property(strong) GCDAsyncSocket *connectedSocket;
@property(nonatomic, strong) GCDAsyncSocket *serverSocket;
@property(nonatomic) BOOL isRunning;

- (void)startAcceptingConnections;

- (void)stopAcceptingConnections;

@end

