//
//  IQDownloadManager.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IQSerialization.h"
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

@interface IQTransferItem : NSObject
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
- (NSString*) valueForResponseHeaderField:(NSString*)field;
@end

@interface IQTransferManager : NSObject
- (IQTransferItem*) downloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadDataProgressivelyFromURL:(NSURL*)url handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadFromURL:(NSURL*)url toFile:(NSFileHandle*)file done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;
- (IQTransferItem*) downloadFromURL:(NSURL*)url toPath:(NSString*)path done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler;

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

@property (nonatomic) BOOL paused;
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
