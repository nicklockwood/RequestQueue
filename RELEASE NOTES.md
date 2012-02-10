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