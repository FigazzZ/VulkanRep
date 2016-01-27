//
//  VideoTrimmer.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 26/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface VideoTrimmer : NSObject

@property(nonatomic) NSURL *fileURL;

- (BOOL)trimVideoAtURL:(NSURL *)videoURL atRange:(CMTimeRange)range;

@end
