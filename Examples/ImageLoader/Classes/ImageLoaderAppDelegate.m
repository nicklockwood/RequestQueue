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

@synthesize window;
@synthesize navigationController;

- (BOOL)application:(__unused UIApplication *)application didFinishLaunchingWithOptions:(__unused NSDictionary *)launchOptions
{    
	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
	return YES;
}

@end

