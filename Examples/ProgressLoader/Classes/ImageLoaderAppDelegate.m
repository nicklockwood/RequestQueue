//
//  ImageLoaderAppDelegate.m
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright Charcoal Design 2012
//

#import "ImageLoaderAppDelegate.h"
#import "RootViewController.h"


@implementation ImageLoaderAppDelegate

- (BOOL)application:(__unused UIApplication *)application didFinishLaunchingWithOptions:(__unused NSDictionary *)launchOptions
{    
	self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
	return YES;
}

@end

