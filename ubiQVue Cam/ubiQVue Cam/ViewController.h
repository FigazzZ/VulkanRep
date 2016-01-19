//
//  ViewController.h
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property(weak, nonatomic) IBOutlet UIImageView *wifiImage;
@property(weak, nonatomic) IBOutlet UIView *gridView;
@property(weak, nonatomic) IBOutlet UIView *controls;
@property(weak, nonatomic) IBOutlet UIView *logoView;
@property(weak, nonatomic) IBOutlet UIButton *aimMode;
@property(weak, nonatomic) IBOutlet UIButton *cameraMode;
@property(weak, nonatomic) IBOutlet UIImageView *logo;
@property(weak, nonatomic) IBOutlet UILabel *versionLabel;
@property(nonatomic, readonly) double timeOffset;

- (IBAction)switchToAimMode:(id)sender;

- (IBAction)switchToCameraMode:(id)sender;

@end
