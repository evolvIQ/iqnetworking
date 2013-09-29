IQNetworking Framework for iOS and OS X
=======================================
*Asynchronous networking for iOS and OS X made simple*


IQNetworking is a simple drop-in framework that provides easy-to-use, robust and low-overhead support for 
common networking tasks in your apps. The following features are included

* Asynchronous HTTP request manager with decoders for common serializations
* Asynchronous, minimalistic HTTP server
* MIME type parser
* File synchronizer/cache to provide transparent offline access to online resources

The library focuses on ease of use/integration and low resource use.

The library is provided under an Apache 2.0 lincense and is free of charge even in commercial applications.

How to use IQNetworking
-----------------------

**Example 1: Creating a web server**

    // Instantiate the server
    IQHTTPServer* server = [IQHTTPServer new];
    // Add any number of resources
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/hello" options:0 error:nil] 
        callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        
        [request writeString:@"Hello, world!"];
        [request done];
    }];
    // Resources can have parameters
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/world/[0-9]+" options:0 error:nil] 
        callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        
        [request writeString:@"Hello, again!"];
        [request done];
    }];
    
    // Start the server (it will serve requests in the background until it is stopped).
    server.started = YES;




