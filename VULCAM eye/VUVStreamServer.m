//
//  VUVStreamServer.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 18/08/15.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import "VUVStreamServer.h"
#import "VUVCamNotificationNames.h"

NSString *const kQVStreamBoundary = @"boundary";

@implementation VUVStreamServer {
    dispatch_queue_t socketQueue;
    NSString *msg;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        socketQueue = dispatch_queue_create("socketQueue", NULL);
        _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                   delegateQueue:dispatch_get_main_queue()
                                                     socketQueue:socketQueue];
        _isRunning = NO;
        msg = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\n"
                                                 "Server: Vulcan\r\n"
                                                 "Connection: close\r\n"
                                                 "Max-Age: 0\r\n"
                                                 "Expires: 0\r\n"
                                                 "Cache-Control: no-store, no-cache, must-revalidate,"
                                                 "pre-check=0, post-check=0, max-age=0\r\n"
                                                 "Pragma: no-cache\r\n"
                                                 "Content-Type: multipart/x-mixed-replace;"
                                                 "boundary=%@\r\n"
                                                 "\r\n--%@\r\n",
                                         kQVStreamBoundary,
                                         kQVStreamBoundary];
    }
    return self;
}

- (void)startAcceptingConnections {
    if (!_isRunning) {
        NSError *error = nil;
        [_serverSocket acceptOnPort:8080 error:&error];
        if (error != nil) {
            NSLog(@"Creating the stream socket failed due to: %@", error.localizedDescription);
        }
        else {
            _isRunning = YES;
        }
    }
}

- (void)closeSocket {
    @synchronized (_connectedSocket) {
        if (_connectedSocket != nil) {
            [_connectedSocket disconnect];
            _connectedSocket = nil;
        }
    }
}

- (void)stopAcceptingConnections {
    [_serverSocket disconnect];
    [self closeSocket];
    _isRunning = NO;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (![_connectedSocket.connectedHost isEqualToString:newSocket.connectedHost]) {
        [self closeSocket];
        _connectedSocket = newSocket;
        _connectedSocket.delegate = self;
    }
    [_connectedSocket writeData:[msg dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
}

- (void)sendStreamNotification:(NSString *)message {
    [[NSNotificationCenter defaultCenter] postNotificationName:kNNStream object:self
                                                      userInfo:@{@"message" : message}];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    // This method is executed on the socketQueue (not the main thread)
    if (tag == 0) {
        [self sendStreamNotification:@"start"];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (sock != _serverSocket) {
        [self sendStreamNotification:@"stop"];
    }
}

- (void)writeImageToSocket:(UIImage *)image withTimestamp:(NSTimeInterval)timestamp {
    if (_connectedSocket != nil) {
        NSData *imgAsJPEG = UIImageJPEGRepresentation(image, 0.1);
        NSString *content = [NSString stringWithFormat:@"Content-type: image/jpeg\r\n"
                                                               "Content-Length:"
                                                               "%lu\r\n"
                                                               "X-Timestamp:"
                                                               "%lu\r\n\r\n",
                                                       (unsigned long) imgAsJPEG.length,
                                                       (unsigned long) timestamp];
        NSString *end = [NSString stringWithFormat:@"\r\n--%@\r\n",
                                                   kQVStreamBoundary];
        [_connectedSocket writeData:[content dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
        [_connectedSocket writeData:imgAsJPEG withTimeout:-1 tag:2];
        [_connectedSocket writeData:[end dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:3];
    }
    else {
        NSLog(@"socket was nil");
    }
}

@end
