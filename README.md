Purpose
--------------

RequestQueue is a simple class for managing multiple concurrent asynchronous URL requests in your applications.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 5.0 / Mac OS 10.7 (Xcode 4.2, Apple LLVM compiler 3.0)
* Earliest supported deployment target - iOS 4.3 / Mac OS 10.6
* Earliest compatible deployment target - iOS 4.0 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

RequestQueue makes use of the ARC Helper library to automatically work with both ARC and non-ARC projects through conditional compilation. There is no need to exclude RequestQueue files from the ARC validation process, or to convert RequestQueue using the ARC conversion tool.


Thread Safety
--------------

You can create RequestQueue instances on any thread, but each instance should only be used on a single thread. The mainQueue shared instance should only be used on the main thread.


Installation
--------------

To use RequestQueue in an app, just drag the RequestQueue class files into your project. RequestQueue has no dependencies.


Properties
------------

	@property (nonatomic, assign) NSUInteger maxConcurrentConnectionCount;
	
This is the maximum number of concurrent connections. If more requests than this are added to the queue, they will be queued until the previous requests have completed. A value of 0 means that there is no limit to the number of concurrent connections. A value of 1 means that only one request will be active at a time, and will ensure that requests are completed in the same order that they are added (assuming `queueMode` is `RequestQueueModeFirstInFirstOut`). The default value is 2.
	
	@property (nonatomic, assign, getter = isSuspended) BOOL suspended;
	
This property toggles whether the queued requests should be started or not. Requests that are already in progress will not be affected by toggling this property, but if suspended = YES, no new connections will be started until it is set to NO again. Setting this property to NO will immediately start the next queued requests downloading.
	
	@property (nonatomic, assign, readonly) NSUInteger requestCount;
	
The number of requests in the queue. This includes both active connections and waiting requests.
	
	@property (nonatomic, strong, readonly) NSArray *requests;

The requests in the queue. This includes both active connections and waiting requests.

    @property (nonatomic, assign) RequestQueueMode queueMode;
    
The queueMode property controls whether new request are added at the front or the back of the queue. The default value of `RequestQueueModeFirstInFirstOut` puts new requests at the back of the queue and the `RequestQueueModeLastInFirstOut` value puts them at the front. Last-in-first-out means that the more recent request is given priority. Connections that are already active will still finish first, but if a large backlog of requests builds up in the queue, newer requests will not be forced to wait until the backlog is cleared before they are dealt with.


Methods
------------

The RequestQueue class has the following methods:

	+ (RequestQueue *)mainQueue;
	
This returns a singleton shared instance of the request queue that can be used anywhere in your app (not thread safe, should only be called from the main thread). It is also perfectly acceptable to create your own queue instance for more finely-grained control over concurrency (for example, you could create a low-priority queue instance and a high priority queue so that your app can perform high-priority requests without them getting stuck behind a low priority request, waiting for it to finish).

	- (void)addRequest:(NSURLRequest *)request completionHandler:(ConnectionCompletionHandler)completionHandler;
	
This adds a new request to the queue. If there are fewer than `maxConcurrentConnectionCount` requests already in the queue, this will start immediately. Note that the same request can be added to the queue multiple times and will be downloaded multiple times. If you want to avoid adding a request to the queue more than once, check if the `requests` property of the queue already contains the request before adding it. Note that although requests are initiated in the order in which they were added (first in, first out), there is no guarantee that they will complete in the same order, unless the `maxConcurrentConnectionCount` is set to 1.
	
	- (void)cancelRequest:(NSURLRequest *)request;
	
This method will cancel the request if it is in progress and remove it from the queue. Regardless of whether the request has started or not, the completion handler block will receive the error `NSURLErrorCancelled`.
	
	- (void)cancelAllRequests;
	
This method will cancel all active and queued requests and remove them from the queue.
	

Callbacks
------------

RequestQueue defines the following callback block function that you can use to be notified when a request completes. See the `addRequest:completionHandler` method for details.

	typedef void (^ConnectionCompletionHandler)(NSURLResponse *response, NSData *data, NSError *error);

Upon completion of a request download, your callback will be called with these arguments. If the request was successful, the error parameter will be nil. In the event of an error, response and data may be nil or may not, depending on when the request failed. If the request was cancelled, the error code will be `NSURLErrorCancelled`.