Version 1.5.1

- Fixed a potential issue where cancelling a request during the autoRetry delay period would not work correctly

Version 1.5

- Now requires ARC (see README for details)
- Fixed bug that prevented autoRetry from working correctly
- You can now specify the autoRetry delay period

Version 1.4.1

- Fixed issue where RQOperation would not work if added to NSOperationQueue other than mainQueue
- Updated ARC Helper library

Version 1.4

- HTTP status codes >= 400 are now treated as errors
- Added RQAuthenticationChallengeHandler for handling HTTP basic auth
- Renamed RequestOperation to RQOperation
- Name-spaced the request handler block function signatures
- Added BasicAuth example project

Version 1.3

- Added `autoRetry` property to RequestOperation class
- Added `allowDuplicateRequests` property to RequestQueue class
- If a duplicate request is added to the queue, the previous duplicate is now cancelled by default

Version 1.2

- Major internal rewrite using NSOperations
- Added new RequestOperation class for individual requests
- Added upload and download progress callbacks
- Renamed all instances of 'Connection' to 'Request' for consistency
- Fixed leak of finished requests
- Simplified image loader example
- Added progress loader example

Version 1.1.1

- Now handles case where expectedContentLength returns -1

Version 1.1

- Added mode property to control queuing
- Fixed some memory leaks when not running under ARC
- Eliminated analyzer warnings

Version 1.0

- Initial release