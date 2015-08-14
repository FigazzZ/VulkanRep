//
//  VVUtility.h
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VVUtility : NSObject

+ (NSString *)convertNSDictToJSONString:(NSDictionary *)dict;

+ (NSDictionary *)getNSDictFromJSONString:(NSString *)JSONString;

@end
