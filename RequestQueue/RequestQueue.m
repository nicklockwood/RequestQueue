//
//  RequestQueue.h
//
//  Version 1.1.1
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


@interface RequestQueueConnection : NSURLConnection

@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;
@property (nonatomic, strong) NSURLResponse *responseReceived;
@property (nonatomic, strong) NSMutableData *accumulatedData;
@property (nonatomic, copy) ConnectionCompletionHandler completionHandler;
@property (nonatomic, assign, readonly, getter = isStarted) BOOL started;

@end


@implementation RequestQueueConnection

@synthesize originalRequest;
@synthesize responseReceived;
@synthesize accumulatedData;
@synthesize completionHandler;
@synthesize started;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately
{
    if ((self = [super initWithRequest:request delegate:delegate startImmediately:startImmediately]))
    {
        originalRequest = AH_RETAIN(request);
    }
    return self;
}

- (void)start
{
    started = YES;
    [super start];
}

- (void)cancel
{
    if (completionHandler)
    {
        completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
    }
    [super cancel];
}

- (void)dealloc
{
    AH_RELEASE(originalRequest);
    AH_RELEASE(responseReceived);
    AH_RELEASE(accumulatedData);
    AH_RELEASE(completionHandler);
    AH_SUPER_DEALLOC;
}

@end


@interface RequestQueue () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableArray *connections;

@end


@implementation RequestQueue

@synthesize maxConcurrentConnectionCount;
@synthesize suspended;
@synthesize connections;
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
        connections = [[NSMutableArray alloc] init];
        maxConcurrentConnectionCount = 2;
    }
    return self;
}

- (void)dealloc
{
    AH_RELEASE(connections);
    AH_SUPER_DEALLOC;
}

- (NSUInteger)requestCount
{
    return [connections count];
}

- (NSArray *)requests
{
    return [connections valueForKeyPath:@"originalRequest"];
}

- (void)dequeueConnections
{
    if (!suspended)
    {
        NSInteger count = maxConcurrentConnectionCount ?: INT_MAX;
        for (RequestQueueConnection *connection in connections)
        {
            if (count == 0)
            {
                break;
            }
            else
            {
                if (![connection isStarted])
                {
                    [connection start];
                }
                count --;
            }
        }
    }
}

#pragma mark Public methods

- (void)setSuspended:(BOOL)_suspended
{
    suspended = _suspended;
    if (!suspended)
    {
        [self dequeueConnections];
    }
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(ConnectionCompletionHandler)completionHandler
{
    RequestQueueConnection *connection = [[RequestQueueConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    connection.completionHandler = completionHandler;
    NSInteger index = 0;
    if (queueMode == RequestQueueModeFirstInFirstOut)
    {
        index = [connections count];
    }
    else
    {
        for (index = 0; index < [connections count]; index++)
        {
            if (![[connections objectAtIndex:index] isStarted])
            {
                break;
            }
        }
    }
    if (index < [connections count])
    {
        [connections insertObject:connection atIndex:index];
    }
    else
    {
        [connections addObject:connection];
    }
    AH_RELEASE(connection);
    [self dequeueConnections];
}

- (void)cancelRequest:(NSURLRequest *)request
{
    for (int i = [connections count] - 1; i >= 0 ; i--)
    {
        RequestQueueConnection *connection = AH_AUTORELEASE(AH_RETAIN([connections objectAtIndex:i]));
        if (connection.originalRequest == request)
        {
            [connections removeObjectAtIndex:i];
            [connection cancel];
        }
    }
}

- (void)cancelAllRequests
{
    NSArray *connectionsCopy = AH_AUTORELEASE(AH_RETAIN(connections));
    self.connections = [NSMutableArray array];
    for (RequestQueueConnection *connection in connectionsCopy)
    {
        [connection cancel];
    }
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(RequestQueueConnection *)connection didFailWithError:(NSError *)error
{
    if ([connections containsObject:connection])
    {
        [connections removeObject:AH_AUTORELEASE(AH_RETAIN(connection))];
        if (connection.completionHandler)
        {
            connection.completionHandler(connection.responseReceived, connection.accumulatedData, error);
        }
        [self dequeueConnections];
    }
}

- (void)connection:(RequestQueueConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([connections containsObject:connection])
    {
        connection.responseReceived = response;
    }
}

- (void)connection:(RequestQueueConnection *)connection didReceiveData:(NSData *)data
{
    if ([connections containsObject:connection])
    {
        if (connection.accumulatedData == nil)
        {
            connection.accumulatedData = [NSMutableData dataWithCapacity:MAX(0, connection.responseReceived.expectedContentLength)];
        }
        [connection.accumulatedData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(RequestQueueConnection *)connection
{
    if ([connections containsObject:connection])
    {
        [connections removeObject:AH_AUTORELEASE(AH_RETAIN(connection))];
        if (connection.completionHandler)
        {
            connection.completionHandler(connection.responseReceived, connection.accumulatedData, nil);
        }
        [self dequeueConnections];
    }
}

@end
