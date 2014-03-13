//
//  RequestQueue.h
//
//  Version 1.5.3
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


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wgnu"


NSString *const HTTPResponseErrorDomain = @"HTTPResponseErrorDomain";


@interface RQOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *responseReceived;
@property (nonatomic, strong) NSMutableData *accumulatedData;
@property (nonatomic, getter = isExecuting) BOOL executing;
@property (nonatomic, getter = isFinished) BOOL finished;
@property (nonatomic, getter = isCancelled) BOOL cancelled;

@end


@implementation RQOperation

+ (instancetype)operationWithRequest:(NSURLRequest *)request
{
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if ((self = [self init]))
    {
        _request = request;
        _autoRetryDelay = 5.0;
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
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
        if (!self.executing && !self.cancelled)
        {
            [self willChangeValueForKey:@"isExecuting"];
            self.executing = YES;
            [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [self.connection start];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)cancel
{
    @synchronized (self)
    {
        if (!self.cancelled)
        {
            [self willChangeValueForKey:@"isCancelled"];
            self.cancelled = YES;
            [self.connection cancel];
            [self didChangeValueForKey:@"isCancelled"];
            
            //call callback
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self connection:self.connection didFailWithError:error];
        }
    }
}

- (void)finish
{
    @synchronized (self)
    {
        if (self.executing && !self.finished)
        {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            self.executing = NO;
            self.finished = YES;
            [self didChangeValueForKey:@"isFinished"];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (NSSet *)autoRetryErrorCodes
{
    if (!_autoRetryErrorCodes)
    {
        static NSSet *codes = nil;
        if (!codes)
        {
            codes = [NSSet setWithObjects:
                     @(NSURLErrorTimedOut),
                     @(NSURLErrorCannotFindHost),
                     @(NSURLErrorCannotConnectToHost),
                     @(NSURLErrorDNSLookupFailed),
                     @(NSURLErrorNotConnectedToInternet),
                     @(NSURLErrorNetworkConnectionLost),
                     nil];
        }
        return codes;
    }
    return _autoRetryErrorCodes;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(__unused NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.autoRetry && [self.autoRetryErrorCodes containsObject:@(error.code)])
    {
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [self.connection performSelector:@selector(start) withObject:nil afterDelay:self.autoRetryDelay];
    }
    else
    {
        [self finish];
        if (self.completionHandler) self.completionHandler(self.responseReceived, self.accumulatedData, error);
    }
}

- (void)connection:(__unused NSURLConnection *)_connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (self.authenticationChallengeHandler)
    {
        self.authenticationChallengeHandler(challenge);
    }
    else
    {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(__unused NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseReceived = response;
}

- (void)connection:(__unused NSURLConnection *)connection didSendBodyData:(__unused NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (self.uploadProgressHandler)
    {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        self.uploadProgressHandler(progress, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connection:(__unused NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self.accumulatedData == nil)
    {
        self.accumulatedData = [[NSMutableData alloc] initWithCapacity:MAX(0, self.responseReceived.expectedContentLength)];
    }
    [self.accumulatedData appendData:data];
    if (self.downloadProgressHandler)
    {
        NSInteger bytesTransferred = [self.accumulatedData length];
        NSInteger totalBytes = MAX(0, self.responseReceived.expectedContentLength);
        self.downloadProgressHandler((float)bytesTransferred / (float)totalBytes, bytesTransferred, totalBytes);
    }
}

- (void)connectionDidFinishLoading:(__unused NSURLConnection *)_connection
{
    [self finish];
    
    NSError *error = nil;
    if ([self.responseReceived respondsToSelector:@selector(statusCode)])
    {
        //treat status codes >= 400 as an error
        NSInteger statusCode = [(NSHTTPURLResponse *)self.responseReceived statusCode];
        if (statusCode / 100 >= 4)
        {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The server returned a %i error", @"RequestQueue HTTPResponse error message format"), statusCode];
            NSDictionary *infoDict = @{NSLocalizedDescriptionKey: message};
            error = [NSError errorWithDomain:HTTPResponseErrorDomain
                                        code:statusCode
                                    userInfo:infoDict];
        }
    }
    
    if (self.completionHandler) self.completionHandler(self.responseReceived, self.accumulatedData, error);
}

@end


@interface RequestQueue () <NSURLConnectionDataDelegate>

@property (strong, nonatomic) NSMutableArray *operations;

@end


@implementation RequestQueue

+ (instancetype)mainQueue
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
        _queueMode = RequestQueueModeFirstInFirstOut;
        _operations = [[NSMutableArray alloc] init];
        _maxConcurrentRequestCount = 2;
        _allowDuplicateRequests = NO;
    }
    return self;
}

- (NSUInteger)requestCount
{
    return [self.operations count];
}

- (NSArray *)requests
{
    return [self.operations valueForKeyPath:@"request"];
}

- (void)dequeueOperations
{
    if (!self.suspended)
    {
        NSInteger count = MIN([self.operations count], self.maxConcurrentRequestCount ?: INT_MAX);
        for (int i = 0; i < count; i++)
        {
            [(RQOperation *)self.operations[i] start];
        }
    }
}

#pragma mark Public methods

- (void)setSuspended:(BOOL)suspended
{
    _suspended = suspended;
    [self dequeueOperations];
}

- (void)addOperation:(RQOperation *)operation
{
    if (!self.allowDuplicateRequests)
    {
        for (RQOperation *op in [self.operations reverseObjectEnumerator])
        {
            if ([op.request isEqual:operation.request])
            {
                [op cancel];
            }
        }
    }
    
    NSUInteger index = 0;
    if (self.queueMode == RequestQueueModeFirstInFirstOut)
    {
        index = [self.operations count];
    }
    else
    {
        for (RQOperation *op in self.operations)
        {
            if (![op isExecuting])
            {
                break;
            }
            index ++;
        }
    }
    if (index < [self.operations count])
    {
        [self.operations insertObject:operation atIndex:index];
    }
    else
    {
        [self.operations addObject:operation];
    }
    
    [operation addObserver:self forKeyPath:@"isExecuting" options:NSKeyValueObservingOptionNew context:NULL];
    [self dequeueOperations];
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(RQCompletionHandler)completionHandler
{
    RQOperation *operation = [RQOperation operationWithRequest:request];
    operation.completionHandler = completionHandler;
    [self addOperation:operation];
}

- (void)cancelRequest:(NSURLRequest *)request
{
    for (RQOperation *op in [self.operations reverseObjectEnumerator])
    {
        if (op.request == request)
        {
            [op cancel];
        }
    }
}

- (void)cancelAllRequests
{
    NSArray *operationsCopy = self.operations;
    self.operations = [NSMutableArray array];
    [operationsCopy makeObjectsPerformSelector:@selector(cancel)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(__unused NSDictionary *)change context:(__unused void *)context
{
    if ([keyPath isEqualToString:@"isExecuting"])
    {
        RQOperation *operation = object;
        if (!operation.executing)
        {
            [operation removeObserver:self forKeyPath:keyPath];
            [self.operations removeObject:operation];
            [self dequeueOperations];
        }
    }
}

@end
