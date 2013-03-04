//
//  IQDownloadManager.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IQSerialization.h"
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
 Blocks execution until all ongoing transfers are finished.
 */
- (void) waitUntilEmpty;
@end
