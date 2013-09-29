//
//  IQHTTPServer.h
//  IQNetworking for iOS and Mac OS X
//
//  Copyright 2012 Rickard Petzäll, EvolvIQ
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

@class IQHTTPServerRequest;

typedef void (^IQHTTPRequestCallback)(IQHTTPServerRequest* request, NSInteger sequence);
typedef void (^IQHTTPRequestReader)(IQHTTPServerRequest* request, NSData* data);
typedef void (^IQHTTPResponseReader)(IQHTTPServerRequest* request, NSMutableData* data, NSUInteger neededBytes);

/**
 A simple but efficient web server using asynchronous sockets, which makes it able to process
 a large number of requests in parallel using only one thread.
 */
@interface IQHTTPServer : NSObject

- (id) init;
- (id) initWithPort:(UInt16)port;
- (id) initWithAddress:(NSString*)address port:(UInt16)port;

- (void) addURLPattern:(NSRegularExpression*)pattern callback:(IQHTTPRequestCallback)callback;
- (void) addURLPattern:(NSRegularExpression*)pattern directory:(NSString*)staticFileDirectory;

/**
 The default callback function used if there are no URL patterns or if no URL pattern matches. If
 this property is not set, the default behaviour is to return a 404 ("Not found") response to the
 client.
 
 NOTE: If buffering is disabled, the callback routine will be called multiple times per request when 
 there is data to write, until the request is completed by sending the [request done] message. The 
 reason for this pattern is to eliminate the need for blocking writes entirely.
 */
@property (nonatomic, copy) IQHTTPRequestCallback callback;

/**
 The port number used by the server. If 0 (the default) a random free port number is used.
 */
@property (nonatomic) UInt16 port;
@property (nonatomic, retain) NSString* address;
@property (nonatomic, retain) NSRunLoop* runLoop;

@property (nonatomic, readonly) NSError* lastError;

/**
 Set to YES to schedule the server to be started. If startup fails for any reason (for
 example occupied port number), the value of this property is set to NO and the lastError
 property contains the error.
 */
@property (nonatomic) BOOL started;

/**
 Keep-alive timeout value in seconds.
 If > 0 (the default is 10.0), allows keep-alive connections if the client requests them. A
 keep-alive connection is kept open to serve multiple requests.
 */
@property (nonatomic) NSTimeInterval keepAliveTimeout;

/**
 The default buffer limit. See IQHTTPServerRequest.writeBufferLimit.
 
 The default is 1MB.
 */
@property (nonatomic) NSUInteger writeBufferLimit;

/**
 Closes idle or all incoming connections to this server.
 @param force If YES, close all connections (even the ones currently
              transmitting data). If NO, close only the idle connections
              maintained by using the keep-alive setting.
 */
- (void) closeAllConnectionsForce:(BOOL)force;

@end


/**
 Represents a single HTTP request, and builds its response.
 */
@interface IQHTTPServerRequest : NSObject
@property (nonatomic, readonly) IQHTTPServer* server;

/**
 Reads the request body asynchronously.
 @param atomic Enables buffering of the content body, and calls the reader
               callback once the entire body has been read.
 */
- (void) readRequestBody:(IQHTTPRequestReader)reader atomic:(BOOL)atomic;
@property (nonatomic, readonly) long long requestBodyLength;

- (NSString*) valueForRequestHeaderField:(NSString*)field;

/**
 Close connection immediately and cancel the request.
 */
- (void) cancel;

/**
 Indicate that all response to this request has been written.
 */
- (void) done;

@property (nonatomic) NSInteger statusCode;

/**
 The maximum size of the write buffer. If writing data faster than the client
 can receive and this buffer is overrun, an exception will be raised. Set to
 zero to disable buffering. A write operation will never block.
 
 The recommendation is to enable buffering for simplicity when handling small 
 requests such as generated strings, and to disable buffering when serving large
 files.
 
 The default is to use the global writeBufferLimit for the server.
 */
@property (nonatomic) NSUInteger writeBufferLimit;

- (void) setValue:(NSString*)value forResponseHeaderField:(NSString *)field;
- (NSString*) valueForResponseHeaderField:(NSString*)field;

/**
 Writes a string to the client, using the character encoding set in the Content-type
 header (if not set, the default is UTF-8).
 
 If buffering is disabled, there is no way of determining that the entire string was 
 written.
 */
- (void) writeString:(NSString*)string;

/**
 Writes data to the client.
 
 @return The number of bytes handled (buffered or sent).
 */
- (NSInteger) writeData:(NSData*)data;

- (void) writeStream:(NSInputStream*)stream;

/**
 Writes a block of bytes to the client. This method will never block. If buffering
 is disabled, the method will return the number of bytes sent. If buffering is enabled,
 the method will accept all bytes up to the maximum buffer limit (in which case an exception
 is raised).
 
 @return The number of bytes handled (buffered or sent). Important: Unlike the NSOutputStream counterpart,
         this method can actually return zero even if the stream will eventually accept more data. This
         occurs when previously buffered data (e.g. HTTP headers) is still being sent.
 */
- (NSInteger) write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL) hasSpaceAvailable;
@end
