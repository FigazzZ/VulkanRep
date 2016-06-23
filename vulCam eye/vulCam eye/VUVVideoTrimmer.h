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

+ (BOOL)trimImpactVideoAtURL:(NSURL *)videoURL
              withImpactTime:(CMTime)impactTime
                   timeAfter:(float)timeAfter
                  timeBefore:(float)timeBefore;

+ (BOOL)trimVideoBeginningAtUrl:(NSURL *)videoURL
              withSecondsToTrim:(NSTimeInterval)secondsToTrim;

@end
