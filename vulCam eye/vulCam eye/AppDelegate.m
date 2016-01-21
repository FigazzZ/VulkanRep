//
//  AppDelegate.m
//  ubiQVue Cam
//
//  Created by Juuso Kaitila on 11.8.2015.
//  Copyright (c) 2015 Bitwise Oy. All rights reserved.
//

#import "AppDelegate.h"
#import "CameraSettings.h"
#import "CommonNotificationNames.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    NSDictionary *appDefaults = @{@"framerate" : @120.0F,
            @"yaw" : @0,
            @"pitch" : @0,
            @"dist" : @10,
            @"uuid" : [NSUUID UUID].UUIDString,
            @"shutterSpeed" : @125};
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    if (getenv("NSZombieEnabled") || getenv("NSAutoreleaseFreedObjectCheckEnabled")) {
        NSLog(@"NSZombieEnabled/NSAutoreleaseFreedObjectCheckEnabled enabled!");
    }

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [UIScreen mainScreen].brightness = 0.5;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[CameraSettings sharedVariables] saveSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNNCloseAll object:self];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[NSNotificationCenter defaultCenter] postNotificationName:kNNRestoreAll object:self];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

}

@end
