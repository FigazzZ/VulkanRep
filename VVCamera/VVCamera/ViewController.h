//
//  ViewController.h
//  VVCamera
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise. All rights reserved.

#import <UIKit/UIKit.h>

#define MIN_SERVER_VERSION @"0.3.0.0"

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *wifiImage;
@property (weak, nonatomic) IBOutlet UIView *gridView;
@property (weak, nonatomic) IBOutlet UIButton *aimMode;
@property (weak, nonatomic) IBOutlet UIButton *cameraMode;
- (IBAction)switchToAimMode:(id)sender;
- (IBAction)switchToCameraMode:(id)sender;

@end
