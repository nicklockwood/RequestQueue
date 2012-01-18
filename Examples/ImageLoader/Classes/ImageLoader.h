//
//  ImageLoader.h
//  ImageLoader
//
//  Created by Nick Lockwood on 18/01/2012.
//  Copyright 2010 Charcoal Design
//

#import <Foundation/Foundation.h>


extern NSString *const ImageDidLoadNotification;


typedef enum
{
	Idle = 0,
	Loading,
	Loaded
}
LoadingState;


@interface ImageLoader : NSObject

@property (nonatomic, readonly, assign) LoadingState loadingState;

+ (id)sharedLoader;

- (void)loadImages:(NSArray *)urlStrings;
- (void)clearImages;
- (NSUInteger)imageCount;
- (UIImage *)imageAtIndex:(NSUInteger)index;
- (NSString *)imageNameAtIndex:(NSUInteger)index;

@end
