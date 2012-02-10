//
//  RequestQueue.h
//
//  Version 1.2 beta
//
//  Created by Nick Lockwood on 22/12/2011.
//  Copyright (C) 2011 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/RequestQueue
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "RequestQueue.h"


@interface RequestOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *responseReceived;
@property (nonatomic, strong) NSMutableData *accumulatedData;
@property (assign, getter = isExecuting) BOOL executing;
@property (assign, getter = isFinished) BOOL finished;
@property (assign, getter = isCancelled) BOOL cancelled;

@end


@implementation RequestOperation

@synthesize request;
@synthesize connection;
@synthesize responseReceived;
@synthesize accumulatedData;
@synthesize executing;
@synthesize finished;
@synthesize cancelled;
@synthesize completionHandler;
@synthesize uploadProgressHandler;
@synthesize downloadProgressHandler;

+ (RequestOperation *)operationWithRequest:(NSURLRequest *)request
{
    return AH_AUTORELEASE([[self alloc] initWithRequest:request]);
}

- (RequestOperation *)initWithRequest:(NSURLRequest *)_request
{
    if ((self = [self init]))
    {
        request = AH_RETAIN(_request);
        connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    }
    return self;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)start
{
    @synchronized (self)
    {
        if (!executing)
        {
            [self willChangeValueForKey:@"isExecuting"];
            executing = YES;
            [connection start];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)cancel
{
    @synchronized (self)
    {
        if (!cancelled)
        {
            [self willChangeValueForKey:@"isCancelled"];
            cancelled = YES;
            [connection cancel];
			[self didChangeValueForKey:@"isCancelled"];
			
			//call callback
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self connection:connection didFailWithError:error];
        }
    }
}

- (void)finish
{
    @synchronized (self)
    {
        if (!finished)
        {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            executing = NO;
            finished = YES;
            [self didChangeValueForKey:@"isFinished"];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)dealloc
{
    AH_RELEASE(request);
    AH_RELEASE(connection);
    AH_RELEASE(responseReceived);
    AH_RELEASE(accumulatedData);
    AH_RELEASE(completionHandler);
    AH_RELEASE(uploadProgressHandler);
    AH_RELEASE(downloadProgressHandler);
    AH_SUPER_DEALLOC;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self finish];
	if (completionHandler) completionHandler(responseReceived, accumulatedData, error);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseReceived = response;
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)bytesTransferred totalBytesExpectedToWrite:(NSInteger)totalBytes
{
    if (uploadProgressHandler)
    {
        float progress = fmaxf(0.0f, fminf(1.0f, (float)bytesTransferred / (float)totalBytes));
        uploadProgressHandler(progress, bytesTransferred, totalBytes);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (accumulatedData == nil)
    {
        accumulatedData = [[NSMutableData alloc] initWithCapacity:MAX(0, responseReceived.expectedContentLength)];
    }
    [accumulatedData appendData:data];
    if (downloadProgressHandler)
    {
        NSInteger bytesTransferred = [accumulatedData length];
        NSInteger totalBytes = MAX(0, responseReceived.expectedContentLength);
		float progress = fmaxf(0.0f, fminf(1.0f, (float)bytesTransferred / (float)totalBytes));
        downloadProgressHandler(progress, bytesTransferred, totalBytes);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)_connection
{
	[self finish];
    if (completionHandler) completionHandler(responseReceived, accumulatedData, nil);
}

@end


@interface RequestQueue () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableArray *operations;

@end


@implementation RequestQueue

@synthesize maxConcurrentRequestCount;
@synthesize suspended;
@synthesize operations;
@synthesize queueMode;

+ (RequestQueue *)mainQueue
{
    static RequestQueue *mainQueue = nil;
    if (mainQueue == nil)
    {
        mainQueue = [[RequestQueue alloc] init];
    }
    return mainQueue;
}

- (id)init
{
    if ((self = [super init]))
    {
        queueMode = RequestQueueModeFirstInFirstOut;
        operations = [[NSMutableArray alloc] init];
        maxConcurrentRequestCount = 2;
    }
    return self;
}

- (void)dealloc
{
    AH_RELEASE(operations);
    AH_SUPER_DEALLOC;
}

- (NSUInteger)requestCount
{
    return [operations count];
}

- (NSArray *)requests
{
    return [operations valueForKeyPath:@"request"];
}

- (void)dequeueOperations
{
    if (!suspended)
    {
        NSInteger count = MIN([operations count], maxConcurrentRequestCount ?: INT_MAX);
        for (int i = 0; i < count; i++)
        {
			[(RequestOperation *)[operations objectAtIndex:i] start];
        }
    }
}

#pragma mark Public methods

- (void)setSuspended:(BOOL)_suspended
{
    suspended = _suspended;
    [self dequeueOperations];
}

- (void)addRequestOperation:(RequestOperation *)operation
{
	NSInteger index = 0;
    if (queueMode == RequestQueueModeFirstInFirstOut)
    {
        index = [operations count];
    }
    else
    {
        for (index = 0; index < [operations count]; index++)
        {
            if (![[operations objectAtIndex:index] isExecuting])
            {
                break;
            }
        }
    }
    if (index < [operations count])
    {
        [operations insertObject:operation atIndex:index];
    }
    else
    {
        [operations addObject:operation];
    }
    
    [operation addObserver:self forKeyPath:@"isExecuting" options:NSKeyValueChangeSetting context:NULL];
    [self dequeueOperations];
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(RequestCompletionHandler)completionHandler
{
    RequestOperation *operation = [RequestOperation operationWithRequest:request];
    operation.completionHandler = completionHandler;
    [self addRequestOperation:operation];
}

- (void)cancelRequest:(NSURLRequest *)request
{
    for (int i = [operations count] - 1; i >= 0 ; i--)
    {
        RequestOperation *operation = AH_AUTORELEASE(AH_RETAIN([operations objectAtIndex:i]));
        if (operation.request == request)
        {
            [operation cancel];
        }
    }
}

- (void)cancelAllRequests
{
    NSArray *operationsCopy = AH_AUTORELEASE(AH_RETAIN(operations));
    self.operations = [NSMutableArray array];
    for (RequestOperation *operation in operationsCopy)
    {
        [operation cancel];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    RequestOperation *operation = object;
    if (!operation.executing)
    {
        [operation removeObserver:self forKeyPath:@"isExecuting"];
        [operations removeObject:operation];
        [self dequeueOperations];
    }
}

@end
