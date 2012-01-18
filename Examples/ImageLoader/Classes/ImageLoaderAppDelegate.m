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

#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
	return YES;
}

#pragma mark Memory management

- (void)dealloc
{
	[navigationController release];
	[window release];
	[super dealloc];
}


@end

