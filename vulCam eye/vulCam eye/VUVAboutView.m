//
//  VUVAboutView.m
//  vulCam eye
//
//  Created by Juuso Kaitila on 04/01/16.
//  Copyright © 2016 Bitwise. All rights reserved.
//

#import "VUVAboutView.h"
#import "CommonUtility.h"

@implementation WKWebView (Scrolling)

- (void)setScrollEnabled:(BOOL)enabled {
    self.scrollView.scrollEnabled = enabled;
    self.scrollView.panGestureRecognizer.enabled = enabled;
    self.scrollView.bounces = enabled;

    // There is one subview as of iOS 8.1 of class WKScrollView
    for (UIView *subview in self.subviews) {
        if ([subview respondsToSelector:@selector(setScrollEnabled:)]) {
            [(id) subview setScrollEnabled:enabled];
        }

        if ([subview respondsToSelector:@selector(setBounces:)]) {
            [(id) subview setBounces:enabled];
        }

        if ([subview respondsToSelector:@selector(panGestureRecognizer)]) {
            [(id) subview panGestureRecognizer].enabled = enabled;
        }

        // here comes the tricky part, disabling
        for (UIView *subScrollView in subview.subviews) {
            if ([subScrollView isKindOfClass:NSClassFromString(@"WKContentView")]) {
                for (id gesture in subScrollView.gestureRecognizers) {
                    if ([gesture isKindOfClass:NSClassFromString(@"UIWebTouchEventsGestureRecognizer")])
                        [subScrollView removeGestureRecognizer:gesture];
                }
            }
        }
    }

}

@end

@implementation VUVAboutView {
    NSString *htmlString;
    WKWebView *webView;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    webView = [[WKWebView alloc] initWithFrame:self.frame];
    webView.configuration.preferences.javaScriptEnabled = NO;
    //    [webView setScrollEnabled:NO];
    webView.scrollView.maximumZoomScale = 1;
    webView.scrollView.minimumZoomScale = 1;
    htmlString = [self createAboutText];
    webView.opaque = NO;
    [self addSubview:webView];
    [CommonUtility setFullscreenConstraintsForView:webView toSuperview:self];
}

- (NSString *)createAboutText {
    NSMutableString *text = [NSMutableString stringWithString:@"<html><head><title></title></head>"];
    NSString *name = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    [text appendString:@"<body style=\"width: 100%; height: 100%; margin: 0; padding: 2em\">"
            "<div style=\"text-align: center\">"];
    [text appendString:[NSString stringWithFormat:@"<h1>%@</h1>", name]];
    [text appendString:[NSString stringWithFormat:@"<img src=\"%@\" width=\"150px\" "
                                                          "height=\"150px\" alt=\"App Logo\" />", @"AppIcon.png"]];
    [text appendString:[NSString stringWithFormat:@"<h2>Version %@</h2>", version]];
    [text appendString:@"<h2>&copy; 2015-2016 Vulcan Vision Corporation. All rights reserved.</h2></div>"];


    [text appendString:@"<br/><p><b><a href=\"https://github.com/jbenet/ios-ntp\"a>ios-ntp</a></b><br/>"
            "Copyright (c) 2012-2015, Ramsay Consulting"
            " - <a href=\"https://opensource.org/licenses/MIT\">MIT License</a></p>"];

    [text appendString:@"<p style=\"height: 5em\"></p></body></html>"];

    return text.description;
}

- (void)showAboutView {
    [webView loadHTMLString:htmlString baseURL:[NSBundle mainBundle].bundleURL];
}

- (void)closeAboutView {
    [webView stopLoading];
    [webView loadHTMLString:@"about:blank" baseURL:nil];
}

@end
