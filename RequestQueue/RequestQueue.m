//
//  RequestQueue.h
//
//  Version 1.4.1
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


NSString *const HTTPResponseErrorDomain = @"HTTPResponseErrorDomain";


@interface RQOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *responseReceived;
@property (nonatomic, strong) NSMutableData *accumulatedData;
@property (assign, getter = isExecuting) BOOL executing;
@property (assign, getter = isFinished) BOOL finished;
@property (assign, getter = isCancelled) BOOL cancelled;
@property (assign) BOOL success;

@end


@implementation RQOperation

@synthesize request = _request;
@synthesize connection = _connection;
@synthesize responseReceived = _responseReceived;
@synthesize accumulatedData = _accumulatedData;
@synthesize executing = _executing;
@synthesize finished = _finished;
@synthesize cancelled = _cancelled;
@synthesize completionHandler = _completionHandler;
@synthesize uploadProgressHandler = _uploadProgressHandler;
@synthesize downloadProgressHandler = _downloadProgressHandler;
@synthesize authenticationChallengeHandler = _authenticationChallengeHandler;
@synthesize autoRetryErrorCodes = _autoRetryErrorCodes;
@synthesize autoRetry = _autoRetry;

+ (RQOperation *)operationWithRequest:(NSURLRequest *)request
{
    return [[[self alloc] initWithRequest:request] autorelease];
}

- (RQOperation *)initWithRequest:(NSURLRequest *)request
{
    if ((self = [self init]))
    {
        _request = [_request ah_retain];
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
        if (!_executing)
        {
            [self willChangeValueForKey:@"isExecuting"];
            _executing = YES;
            [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [_connection start];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)cancel
{
    @synchronized (self)
    {
        if (!_cancelled)
        {
            [self willChangeValueForKey:@"isCancelled"];
            _cancelled = YES;
            [_connection cancel];
            [self didChangeValueForKey:@"isCancelled"];
            
            //call callback
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self connection:_connection didFailWithError:error];
        }
    }
}

- (void)finish:(BOOL)success
{
    @synchronized (self)
    {
        if (_executing && !_finished)
        {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            _executing = NO;
            _finished = YES;
            _success = success;
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
                     [NSNumber numberWithInt:NSURLErrorTimedOut],
                     [NSNumber numberWithInt:NSURLErrorCannotFindHost],
                     [NSNumber numberWithInt:NSURLErrorCannotConnectToHost],
                     [NSNumber numberWithInt:NSURLErrorDNSLookupFailed],
                     [NSNumber numberWithInt:NSURLErrorNotConnectedToInternet],
                     [NSNumber numberWithInt:NSURLErrorNetworkConnectionLost],
                     nil];
        }
        return codes;
    }
    return _autoRetryErrorCodes;
}

- (void)dealloc
{
    [_request release];
    [_connection release];
    [_responseReceived release];
    [_accumulatedData release];
    [_completionHandler release];
    [_uploadProgressHandler release];
    [_downloadProgressHandler release];
    [_authenticationChallengeHandler release];
    [_autoRetryErrorCodes release];
    [super ah_dealloc];
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (_autoRetry && [self.autoRetryErrorCodes containsObject:[NSNumber numberWithInt:error.code]])
    {
        self.connection = [[[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:NO] autorelease];
        [self.connection performSelector:@selector(start) withObject:nil afterDelay:1.0];
    }
    else
    {
        [self finish:NO];
        if (_completionHandler) _completionHandler(_responseReceived, _accumulatedData, error);
    }
}

- (void)connection:(NSURLConnection *)_connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (_authenticationChallengeHandler)
    {
        _authenticationChallengeHandler(challenge);
    }
    else
    {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseReceived = response;
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    self.uploadBytesTotal = totalBytesExpectedToWrite;
    self.uploadBytesDone = totalBytesWritten;
    if (_uploadProgressHandler)
    {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        _uploadProgressHandler(progress, totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_accumulatedData == nil)
    {
        _accumulatedData = [[NSMutableData alloc] initWithCapacity:MAX(0, _responseReceived.expectedContentLength)];
    }
    [_accumulatedData appendData:data];
    self.downloadBytesTotal = MAX(0, _responseReceived.expectedContentLength);
    self.downloadBytesDone = [_accumulatedData length];
    if (_downloadProgressHandler)
    {
        _downloadProgressHandler((float)self.downloadBytesDone / (float)self.downloadBytesTotal, self.downloadBytesDone, self.downloadBytesTotal);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)_connection
{
    NSError *error = nil;
    if ([_responseReceived respondsToSelector:@selector(statusCode)])
    {
        //treat status codes >= 400 as an error
        NSInteger statusCode = [(NSHTTPURLResponse *)_responseReceived statusCode];
        if (statusCode / 100 >= 4)
        {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The server returned a %i error", @"RequestQueue HTTPResponse error message format"), statusCode];
            NSDictionary *infoDict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:HTTPResponseErrorDomain
                                        code:statusCode
                                    userInfo:infoDict];
        }
    }

    [self finish:(error == nil)];
    if (_completionHandler) _completionHandler(_responseReceived, _accumulatedData, error);
}

@end


@interface RequestQueue () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableArray *operations;

@end


@implementation RequestQueue {
    BOOL _success;
}

@synthesize maxConcurrentRequestCount = _maxConcurrentRequestCount;
@synthesize suspended = _suspended;
@synthesize operations = _operations;
@synthesize queueMode = _queueMode;
@synthesize allowDuplicateRequests = _allowDuplicateRequests;

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
        _queueMode = RequestQueueModeFirstInFirstOut;
        _operations = [[NSMutableArray alloc] init];
        _maxConcurrentRequestCount = 2;
        _allowDuplicateRequests = NO;
        [self clearSuccessFlag];
    }
    return self;
}

- (void)dealloc
{
    [_operations release];
    [super ah_dealloc];
}

- (NSUInteger)requestCount
{
    return [_operations count];
}

- (NSArray *)requests
{
    return [_operations valueForKeyPath:@"request"];
}

- (void)dequeueOperations
{
    if (!_suspended)
    {
        NSInteger count = MIN([_operations count], _maxConcurrentRequestCount ?: INT_MAX);
        for (int i = 0; i < count; i++)
        {
            [(RQOperation *)[_operations objectAtIndex:i] start];
        }
    }

    if ([_operations count] == 0 && self.completionHandler != nil) {
        self.completionHandler(_success);
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
    if (!_allowDuplicateRequests)
    {
        for (int i = [_operations count] - 1; i >= 0 ; i--)
        {
            RQOperation *_operation = [[[_operations objectAtIndex:i] ah_retain] autorelease];
            if ([_operation.request isEqual:operation.request])
            {
                [_operation cancel];
            }
        }
    }
    
    NSInteger index = 0;
    if (_queueMode == RequestQueueModeFirstInFirstOut)
    {
        index = [_operations count];
    }
    else
    {
        for (index = 0; index < [_operations count]; index++)
        {
            if (![[_operations objectAtIndex:index] isExecuting])
            {
                break;
            }
        }
    }
    if (index < [_operations count])
    {
        [_operations insertObject:operation atIndex:index];
    }
    else
    {
        [_operations addObject:operation];
    }
    
    [operation addObserver:self forKeyPath:@"isExecuting" options:NSKeyValueChangeSetting context:NULL];
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
    for (int i = [_operations count] - 1; i >= 0 ; i--)
    {
        RQOperation *operation = [[[_operations objectAtIndex:i] ah_retain] autorelease];
        if (operation.request == request)
        {
            [operation cancel];
        }
    }
}

- (void)cancelAllRequests
{
    NSArray *operationsCopy = [[_operations ah_retain] autorelease];
    self.operations = [NSMutableArray array];
    for (RQOperation *operation in operationsCopy)
    {
        [operation cancel];
    }
}

- (void)clearSuccessFlag {
    _success = YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    RQOperation *operation = object;
    if (!operation.executing)
    {
        if (!operation.success) {
            _success = NO;
        }
        [operation removeObserver:self forKeyPath:@"isExecuting"];
        [_operations removeObject:operation];
        [self dequeueOperations];
    }
}

@end
