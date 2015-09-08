//
//  StreamServer.m
//  VVCamera
//
//  Created by Bitwise on 18/08/15.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "StreamServer.h"

@implementation StreamServer{
    dispatch_queue_t socketQueue;
    NSString *msg;
}

- (id)init
{
    self = [super init];
    if (self){
        socketQueue = dispatch_queue_create("socketQueue", NULL);
        _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue() socketQueue:socketQueue];
        _isRunning = NO;
        msg = [[NSString alloc] initWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@",
               @"HTTP/1.0 200 OK\r\n",
               @"Server: Vulcan\r\n",
               @"Connection: close\r\n",
               @"Max-Age: 0\r\n",
               @"Expires: 0\r\n",
               @"Cache-Control: no-store, no-cache, must-revalidate, pre-check=0, post-check=0, max-age=0\r\n",
               @"Pragma: no-cache\r\n",
               @"Content-Type: multipart/x-mixed-replace; ",
               @"boundary=", BOUNDARY, @"\r\n",
               @"\r\n--", BOUNDARY , @"\r\n"];
    }
    return self;
}

- (void)startAcceptingConnections{
    if (!_isRunning){
        NSError *error = nil;
        [_serverSocket acceptOnPort:8080 error:&error];
        _isRunning = YES;
    }
}

- (void)closeSocket{
    @synchronized(_connectedSocket){
        if(_connectedSocket != nil){
            [_connectedSocket disconnect];
            _connectedSocket = nil;
        }
    }
}

- (void)stopAcceptingConnections{
    [_serverSocket disconnect];
    [self closeSocket];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (![_connectedSocket.connectedHost isEqualToString:newSocket.connectedHost]) {
        [self closeSocket];
        _connectedSocket = newSocket;
        [_connectedSocket setDelegate:self];
    }
    [_connectedSocket writeData:[msg dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void)sendStreamNotification:(NSString *)message {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"StreamNotification"
     object:self
     userInfo:[[NSDictionary alloc] initWithObjects:@[message] forKeys:@[@"message"]]];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    // This method is executed on the socketQueue (not the main thread)
    if (tag == 0) {
        [self sendStreamNotification:@"start"];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (sock != _serverSocket){
        [self sendStreamNotification:@"stop"];
    }
}

@end
