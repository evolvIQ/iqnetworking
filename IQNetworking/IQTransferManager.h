//
//  IQTransferManager.h
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
#import <IQSerialization/IQSerialization.h>
#import "IQProgressAgregator.h"
#import "IQMIMEType.h"

#define kIQTransferManagerErrorDomain @"kIQTransferManagerErrorDomain"

#define kIQTransferCannotWriteFileHandle -1101
#define kIQTransferCannotOpenOutputFile -1102

typedef void (^IQGenericCallback)();
typedef BOOL (^IQDataHandler)(NSData* data);
typedef void (^IQResultHandler)(NSData* result);
typedef void (^IQErrorHandler)(NSError* error);
typedef void (^IQStringHandler)(NSString* string);
typedef void (^IQDictionaryHandler)(NSDictionary* dictionary);

@interface IQTransferItem : NSObject <IQProgressible>
- (void)startImmediately;
/**
 If set to YES, protocol status codes indicating an error will not result in the 
 error handler being called. Instead, the data associated with the status will be
 returned as normal response data. Default is to inherit the value from the parent
 IQTransferManager.
 */
@property (nonatomic) BOOL ignoreErrorStatusCodes;
@property (nonatomic) BOOL followRedirects;

@property (nonatomic, readonly) IQMIMEType* contentType;
@property (nonatomic, retain) IQMIMEType* postDataContentType;
- (NSString*) valueForResponseHeaderField:(NSString*)field;


- (NSString*) valueForRequestHeaderField:(NSString*)field;
- (void) setValue:(NSString*)value forRequestHeaderField:(NSString *)field;

@property (nonatomic, retain) NSData* requestBody;
@property (nonatomic, retain) NSInputStream* requestBodyStream;
@property (nonatomic, retain) NSString* requestMethod;

/**
 Blocks execution until this item transfer has finished.
 
 Avoid using this in a production application (use the handler arguments instead).
 Blocking a thread wastes resources. This method is primarily intended to support unit testing.
 In addition, the implementation of this method is very inefficient.
 */
- (void) waitUntilDone;
@end

@interface IQTransferManager : NSObject
- (IQTransferItem*) downloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) postData:(NSData*)postData andDownloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadDataProgressivelyFromURL:(NSURL*)url handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) postData:(NSData*)postData andDownloadProgressivelyFromURL:(NSURL*)url  handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadFromURL:(NSURL*)url toFile:(NSFileHandle*)file done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadFromURL:(NSURL*)url toPath:(NSString*)path done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;

- (void) setDefaultValue:(NSString*)value forRequestHeaderField:(NSString *)field;

/**
 This callback is called every time the transfer manager has processed all pending requests.
 */
@property (nonatomic, copy) IQGenericCallback doneHandler;

/**
 Download a string from a URL and decode it into an NSString (using text encoding information from the HTTP
 response headers, if available). Default text encoding is UTF-8, unless a text content type without encoding
 was specified by the server (in which case the HTTP standard mandates that Latin-1 is the default encoding).
 */
- (IQTransferItem*) downloadStringFromURL:(NSURL*)url handler:(IQStringHandler)handler errorHandler:(IQErrorHandler)errorHandler;
/**
 Download and deserialize an object.
 */
- (IQTransferItem*) downloadDictionaryFromURL:(NSURL*)url handler:(IQDictionaryHandler)handler format:(IQSerializationFormat)format errorHandler:(IQErrorHandler)errorHandler;
/**
 Serialize and post an object and download and deserialize the response.
 */
- (IQTransferItem*) postObject:(id)object format:(IQSerializationFormat)postFormat andDownloadDictionaryFromURL:(NSURL*)url handler:(IQDictionaryHandler)handler format:(IQSerializationFormat)responseFormat errorHandler:(IQErrorHandler)errorHandler;

/**
 Post the dictionary as a form-encoded data and download the raw response.
 */
- (IQTransferItem*) postForm:(NSDictionary*)formData andDownloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler;

@property (nonatomic) BOOL paused;

/**
 If YES, ignores any cache specified by the protocol (such as the local HTTP cache).
 
 Default is NO, which means caching will be used.
 */
@property (nonatomic) BOOL ignoreCache;

/**
 The default value of ignoreErrorStatusCodes for new transfers initiated through this transfer manager.
 
 Default is NO.
 */
@property (nonatomic) BOOL ignoreErrorStatusCodes;
/**
 The default value of followRedirects for new transfers initiated through this transfer manager.
 
 Default is YES.
 */
@property (nonatomic) BOOL followRedirects;
/**
 The connection idle timeout value for new transfers initiated through this transfer manager.
 
 Default is 10 seconds.
 */
@property (nonatomic) NSTimeInterval timeoutInterval;

/**
 YES if the transfer manager is currently processing network request(s).
 */
@property (atomic, readonly) BOOL isBusy;

/**
 Blocks execution until all ongoing transfers are finished.
 
 Avoid using this in a production application (see the doneHandler property instead).
 Blocking a thread wastes resources. This method is primarily intended to support unit testing.
 In addition, the implementation of this method is very inefficient.
 */
- (void) waitUntilEmpty;
@end
