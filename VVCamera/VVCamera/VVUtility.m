//
//  VVUtility.m
//  VVCamera
//
//  Created by Juuso Kaitila on 13.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.
//

#import "VVUtility.h"

@implementation VVUtility

+ (NSString *)convertNSDictToJSONString:(NSDictionary *)dict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:0
                                                         error:&error];
    
    if (!jsonData) {
        NSLog(@"Error creating cameradata JSON: %@", [error localizedDescription]);
    } else {
        
        NSString *JSONString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
        //NSLog(@"JSONasString %@",JSONString);
        return JSONString;
    }
    return nil;
}

+ (NSDictionary *)getNSDictFromJSONString:(NSString *)JSONString{
    NSError *jsonError;
    NSData *objectData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                                       options:NSJSONReadingMutableContainers
                                                                         error:&jsonError];
    return jsonDict;
}

@end
