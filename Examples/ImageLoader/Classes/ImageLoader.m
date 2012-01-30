//
//  ImageLoader.m
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright 2010 Charcoal Design
//

#import "ImageLoader.h"
#import "RequestQueue.h"


NSString *const ImageDidLoadNotification = @"ImageDidLoadNotification";


@interface ImageLoader()

@property (nonatomic, retain) NSMutableArray *urlStrings;
@property (nonatomic, retain) NSMutableDictionary *images;
@property (nonatomic, assign) LoadingState loadingState;

@end


@implementation ImageLoader

@synthesize urlStrings;
@synthesize images;
@synthesize loadingState;

+ (ImageLoader *)sharedLoader
{
	static ImageLoader *sharedLoader = nil;
	if (sharedLoader == nil)
	{
		sharedLoader = [[self alloc] init];
	}
	return sharedLoader;
}

- (void)dealloc
{	
	[urlStrings release];
	[images release];
	[super dealloc];
}

- (void)loadImages:(NSArray *)_urlStrings
{	
	self.urlStrings = [[_urlStrings mutableCopy] autorelease];
	self.images = [NSMutableDictionary dictionary];
	self.loadingState = Loading;
    
	for (NSString *urlString in _urlStrings)
	{
		NSURL *URL = [NSURL URLWithString:urlString];
        NSURLCacheStoragePolicy policy = NSURLCacheStorageNotAllowed;
		NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:policy timeoutInterval:15.0];
		[[RequestQueue mainQueue] addRequest:request completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            
			if (!error)
			{
				//image downloaded
				UIImage *image = [UIImage imageWithData:data];
				[images setObject:image forKey:urlString];
			}
            else
            {
                //error
                NSInteger index = [urlStrings indexOfObject:urlString];
                [urlStrings replaceObjectAtIndex:index withObject:[error localizedDescription]];
            }
            
            if ([urlStrings count] == [_urlStrings count])
			{
				//finished loading
				self.loadingState = Loaded;
			}
            
            //notify view controller
            [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidLoadNotification object:nil];
		}];
	}
}

- (void)clearImages
{
	self.urlStrings = nil;
	self.images = nil;
	self.loadingState = Idle;
}

//custom setter for loading state, toggles application network activity indicator
- (void)setLoadingState:(LoadingState)_loadingState
{	
	if (loadingState != _loadingState)
	{
		loadingState = _loadingState;
		[UIApplication sharedApplication].networkActivityIndicatorVisible = (loadingState == Loading);
	}
}

- (NSUInteger)imageCount
{
	return [self.urlStrings count];
}

- (UIImage *)imageAtIndex:(NSUInteger)index
{	
	return [self.images objectForKey:[self.urlStrings objectAtIndex:index]];
}

- (NSString *)imageNameAtIndex:(NSUInteger)index
{	
	return [[[self.urlStrings objectAtIndex:index] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end
