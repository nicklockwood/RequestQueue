//
//  RootViewController.h
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright Charcoal Design 2012
//

#import <UIKit/UIKit.h>

@interface RootViewController : UITableViewController

@property (nonatomic, strong) UIBarButtonItem *loadUnloadButton;

- (IBAction)loadUnloadImages;

@end
