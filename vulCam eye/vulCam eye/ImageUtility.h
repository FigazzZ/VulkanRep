//
//  ImageUtility.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 05/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ImageUtility : NSObject

+ (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)newSize;

+ (UIImage *)imageFromSampleBuffer:(CVImageBufferRef)imageBuffer;

@end
