IQNetworking Framework
======================
*Asynchronous networking for iOS and OS X made simple*


IQNetworking is a simple drop-in framework that provides easy-to-use, robust and low-overhead support for 
common networking tasks in your apps. The following features are included

* Asynchronous HTTP request manager with decoders for common serializations
* Asynchronous, minimalistic HTTP server
* MIME type parser
* File synchronizer/cache to provide transparent offline access to online resources

The library focuses on ease of use/integration and low resource use.

The library is provided under an Apache 2.0 license and is free of charge even in commercial applications.

How to use IQNetworking
-----------------------

**How to integrate** (Currently iOS only -- for OS X, open the project with XCode and build from there)
The easiest way to integrate IQNetworking into your project is to build the library from source using the provided Makefile.

    $ git clone --recursive git://github.com/evolvIQ/iqnetworking.git
    $ cd iqnetworking
    $ make
    $ ls Products/*
    Products/Debug:
    IQNetworking.framework
    
    Products/Release:
    IQNetworking.framework
    $
    
Then drag the Debug or Release version of the framework to your app. The framework is a statically compiled universal binary
that works both in the simulator and on devices.
    
**Important**: Do not omit the --recursive flag, as IQNetworking depends on the IQSerialization library.
    

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




