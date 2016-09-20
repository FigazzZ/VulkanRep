//
//  VUVViewController.h
//  vulCam eye
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.

#import <UIKit/UIKit.h>
#import "VULCAM_eye-Swift.h"

@interface VUVViewController : UIViewController

@property(weak, nonatomic) IBOutlet UIImageView *wifiImage;
@property(weak, nonatomic) IBOutlet UIView *gridView;
@property(weak, nonatomic) IBOutlet UIView *controls;
@property(weak, nonatomic) IBOutlet UIView *logoView;
@property(weak, nonatomic) IBOutlet UIButton *aimMode;
@property(weak, nonatomic) IBOutlet UIButton *cameraMode;
@property(weak, nonatomic) IBOutlet UIImageView *logo;
@property(nonatomic, readonly) double timeOffsetInSeconds;
@property VUVAboutViewController *aboutViewController;

- (IBAction)switchToAimMode:(id)sender;

- (IBAction)switchToCameraMode:(id)sender;

- (IBAction)showAboutView:(id)sender;

@end
