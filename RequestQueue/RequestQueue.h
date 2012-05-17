//
//  RequestQueue.h
//
//  Version 1.4
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

//
//  ARC Helper
//
//  Version 1.2.2
//
//  Created by Nick Lockwood on 05/01/2012.
//  Copyright 2012 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://gist.github.com/1563325
//

#ifndef AH_RETAIN
#if __has_feature(objc_arc)
#define AH_RETAIN(x) (x)
#define AH_RELEASE(x) (void)(x)
#define AH_AUTORELEASE(x) (x)
#define AH_SUPER_DEALLOC (void)(0)
#else
#define __AH_WEAK
#define AH_WEAK assign
#define AH_RETAIN(x) [(x) retain]
#define AH_RELEASE(x) [(x) release]
#define AH_AUTORELEASE(x) [(x) autorelease]
#define AH_SUPER_DEALLOC [super dealloc]
#endif
#endif

//  ARC Helper ends


#import <Foundation/Foundation.h>


extern NSString *const HTTPResponseErrorDomain;


typedef void (^RQCompletionHandler)(NSURLResponse *response, NSData *data, NSError *error);
typedef void (^RQProgressHandler)(float progress, NSInteger bytesTransferred, NSInteger totalBytes);
typedef void (^RQAuthenticationChallengeHandler)(NSURLAuthenticationChallenge *challenge);


typedef enum
{
    RequestQueueModeFirstInFirstOut = 0,
    RequestQueueModeLastInFirstOut
}
RequestQueueMode;


@interface RQOperation : NSOperation

@property (nonatomic, strong, readonly) NSURLRequest *request;
@property (nonatomic, copy) RQCompletionHandler completionHandler;
@property (nonatomic, copy) RQProgressHandler uploadProgressHandler;
@property (nonatomic, copy) RQProgressHandler downloadProgressHandler;
@property (nonatomic, copy) RQAuthenticationChallengeHandler authenticationChallengeHandler;
@property (nonatomic, copy) NSSet *autoRetryErrorCodes;
@property (nonatomic, assign) BOOL autoRetry;

+ (RQOperation *)operationWithRequest:(NSURLRequest *)request;
- (RQOperation *)initWithRequest:(NSURLRequest *)request;

@end


@interface RequestQueue : NSObject

@property (nonatomic, assign) NSUInteger maxConcurrentRequestCount;
@property (nonatomic, assign, getter = isSuspended) BOOL suspended;
@property (nonatomic, assign, readonly) NSUInteger requestCount;
@property (nonatomic, strong, readonly) NSArray *requests;
@property (nonatomic, assign) RequestQueueMode queueMode;
@property (nonatomic, assign) BOOL allowDuplicateRequests;

+ (RequestQueue *)mainQueue;

- (void)addOperation:(RQOperation *)operation;
- (void)addRequest:(NSURLRequest *)request completionHandler:(RQCompletionHandler)completionHandler;
- (void)cancelRequest:(NSURLRequest *)request;
- (void)cancelAllRequests;

@end
