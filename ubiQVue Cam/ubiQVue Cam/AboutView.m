//
//  AboutView.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 04/01/16.
//  Copyright © 2016 Bitwise Oy. All rights reserved.
//

#import "AboutView.h"

@implementation AboutView

- (instancetype)init {
    self = [super init];
    if(self){
        [self loadHTMLString:[self createAboutText] baseURL:nil];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self loadHTMLString:[self createAboutText] baseURL:nil];
    }
    return self;
}

- (NSString *)createAboutText {
    NSMutableString *text = [NSMutableString stringWithString:@"<html><head><title></title></head><body>"];
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    [text appendString:[NSString stringWithFormat:@"<h1>%@</h1>", name]];
    [text appendString:[NSString stringWithFormat:@"<h3>Version %@</h3>", version]];
    [text appendString:@"<h3>&copy; 2015-2016 Vulcan Vision Corporation</h3>"];
    
    [text appendString:@"<p><b><a href=\"https://github.com/jbenet/ios-ntp\"a>ios-ntp</a></b><br/>"
    "Copyright (c) 2012-2015, Ramsay Consulting"
    " - <a href=\"#MIT\">MIT License</a></p>"];
    
    return [text description];
}

@end
