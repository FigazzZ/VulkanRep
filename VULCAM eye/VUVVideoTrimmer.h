//
//  VUVVideoTrimmer.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 26/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface VUVVideoTrimmer : NSObject

+ (BOOL)trimImpactVideoAtURL:(NSURL *)sourceURL
              withFrameCount:(NSNumber *)frameCount
                   framerate:(NSNumber *)framerate
                 impactStart:(NSTimeInterval)impactStart
                  impactTime:(NSTimeInterval)impactTime
                   impactEnd:(NSTimeInterval)impactEnd
                  timeBefore:(float)timeBefore
                   timeAfter:(float)timeAfter;


@end
