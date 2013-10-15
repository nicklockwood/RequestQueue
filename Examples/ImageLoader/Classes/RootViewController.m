//
//  RootViewController.m
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright Charcoal Design 2012
//

#import "RootViewController.h"
#import "RequestQueue.h"


@interface RootViewController ()

@property (nonatomic, strong) NSMutableArray *urlStrings;
@property (nonatomic, strong) NSMutableDictionary *images;

@end


@implementation RootViewController

@synthesize loadUnloadButton;
@synthesize urlStrings;
@synthesize images;

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.loadUnloadButton = [[UIBarButtonItem alloc] initWithTitle:@"Load"
															  style:UIBarButtonItemStylePlain
															 target:self
															 action:@selector(loadUnloadImages)];
	
	self.navigationItem.rightBarButtonItem = loadUnloadButton;
	self.navigationItem.title = @"Images";
}

- (void)refreshView
{	
	//reload table data
	[self.tableView reloadData];
	
	//update button state
	if ([[RequestQueue mainQueue] requestCount])
	{
		//loading
		loadUnloadButton.enabled = NO;
		loadUnloadButton.title = @"Wait";
	}
	else if ([urlStrings count])
	{
		//finished
		loadUnloadButton.enabled = YES;
		loadUnloadButton.title = @"Clear";
	}
	else
	{
		//idle
		loadUnloadButton.enabled = YES;
		loadUnloadButton.title = @"Load";
	}
}

- (void)loadUnloadImages
{	
	//select action
	if ([urlStrings count])
	{
		//clear images
		self.urlStrings = nil;
		self.images = nil;
		
		//refresh view
		[self refreshView];
	}
	else
	{
		//reset data source
		NSString *path = [[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"];
		self.urlStrings = [NSMutableArray arrayWithContentsOfFile:path];
		self.images = [NSMutableDictionary dictionary];
		[self refreshView];
		
		//load images
		for (NSString *urlString in urlStrings)
		{
			NSURL *URL = [NSURL URLWithString:urlString];
			NSURLCacheStoragePolicy policy = NSURLCacheStorageNotAllowed;
			NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:policy timeoutInterval:15.0];
			[[RequestQueue mainQueue] addRequest:request completionHandler:^(__unused NSURLResponse *response, NSData *data, NSError *error) {
				
				if (!error)
				{
					//image downloaded
					UIImage *image = [UIImage imageWithData:data];
                    if (image)
                    {
                        images[urlString] = image;
                    }
                    else
                    {
                        //image error
                        NSInteger index = [urlStrings indexOfObject:urlString];
                        urlStrings[index] = @"Image was missing or corrupt";
                    }
				}
				else
				{
					//loading error
					NSInteger index = [urlStrings indexOfObject:urlString];
					urlStrings[index] = [error localizedDescription];
				}
				
				//refresh view
				[self refreshView];
			}];
		}

	}
}

#pragma mark Table view data source

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section
{	
    return [urlStrings count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
	}
    
	NSString *urlString = urlStrings[indexPath.row];
	cell.imageView.image = images[urlString];
	cell.textLabel.text = [urlString lastPathComponent];

    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(__unused UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
	//create view controller
	UIViewController *viewController = [[UIViewController alloc] init];

	//set view
	NSString *urlString = urlStrings[indexPath.row];
	UIImage *image = images[urlString];
	UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
	viewController.view = imageView;
	
	//pass the selected object to the new view controller.
	[self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark Memory management

- (void)viewDidUnload
{	
	self.loadUnloadButton = nil;
	[super viewDidUnload];
}



@end

