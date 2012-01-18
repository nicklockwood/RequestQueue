//
//  RootViewController.m
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright Charcoal Design 2012
//

#import "RootViewController.h"
#import "ImageLoader.h"


@implementation RootViewController

@synthesize loadUnloadButton;

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.loadUnloadButton = [[[UIBarButtonItem alloc] initWithTitle:@"Load"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(loadUnloadImages)] autorelease];
	
	self.navigationItem.rightBarButtonItem = loadUnloadButton;
	self.navigationItem.title = @"Images";
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshView)
												 name:ImageDidLoadNotification
											   object:nil];
}

- (void)refreshView
{	
	//reload table data
	[self.tableView reloadData];
	
	//update button state
	switch ([[ImageLoader sharedLoader] loadingState])
	{
		case Idle:
		{
			self.loadUnloadButton.enabled = YES;
			self.loadUnloadButton.title = @"Load";
			break;
		}
		case Loading:
		{
			self.loadUnloadButton.enabled = NO;
			self.loadUnloadButton.title = @"Wait";
			break;
		}
		case Loaded:
		{
			self.loadUnloadButton.enabled = YES;
			self.loadUnloadButton.title = @"Clear";
			break;
		}
	}
}

- (void)loadUnloadImages
{	
	switch ([[ImageLoader sharedLoader] loadingState])
	{
		case Idle:
		{
			[[ImageLoader sharedLoader] loadImages:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"]]];
			[self refreshView];
			break;
		}
		case Loaded:
		{
			[[ImageLoader sharedLoader] clearImages];
			[self refreshView];
			break;
		}
		default:
		{
			break;
		}
	}
}

#pragma mark Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
    return [[ImageLoader sharedLoader] imageCount];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
    
	cell.imageView.image = [[ImageLoader sharedLoader] imageAtIndex:indexPath.row];
	cell.textLabel.text = [[ImageLoader sharedLoader] imageNameAtIndex:indexPath.row];
	
    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
	//create view controller
	UIViewController *viewController = [[UIViewController alloc] init];

	//set view
	UIImageView *imageView = [[UIImageView alloc] initWithImage:[[ImageLoader sharedLoader] imageAtIndex:indexPath.row]];
	viewController.view = imageView;
	[imageView release];
	
	// Pass the selected object to the new view controller.
	[self.navigationController pushViewController:viewController animated:YES];
	[viewController release];
}

#pragma mark Memory management

- (void)viewDidUnload
{	
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ImageDidLoadNotification object:nil];
	self.loadUnloadButton = nil;
	[super viewDidUnload];
}

- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


@end

