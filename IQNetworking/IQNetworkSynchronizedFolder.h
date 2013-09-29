//
//  IQNetworkSynchronizedFolder.h
//  IQNetworking for iOS and Mac OS X
//
//  Copyright 2013 Rickard Petzäll, EvolvIQ
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

#import "IQTransferManager.h"

#define kIQNetworkSynchronizationErrorDomain @"kIQNetworkSynchronizationErrorDomain"

#define kIQNetworkSynchronizationErrorHandleAlreadyOpen -1001
#define kIQNetworkSynchronizationErrorFileNotInCache -1002
#define kIQNetworkSynchronizationErrorUnableToOpen -1003

@class IQNetworkSynchronizedFile;
typedef NSString* (^IQCacheFileNaming)(NSURL* url);
typedef void (^IQSynchronizedFileOpener)(NSFileHandle* handle);
typedef void (^IQSynchronizedFileNameCallback)(NSString* path);

/**
 Manages a set of files synchronized against a server.
 
 Note: The implementation is currently not optimized for a huge set of files.
 */
@interface IQNetworkSynchronizedFolder : NSObject

+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name;
+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name inParent:(NSString*)path;
- (id)initWithName:(NSString*)name parent:(NSString*)parent;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* localPath;

/**
 YES if the synchronized folder is currently synchronizing one or more entries.
 */
@property (atomic, readonly) BOOL isBusy;

/**
 This callback is called every time the folder has completed all outstanding synchronizations.
 */
@property (nonatomic, copy) IQGenericCallback doneHandler;

/**
 The timeout value for when to re-check cached items against the server.
 Default is one hour.
 */
@property (nonatomic, assign) NSTimeInterval cacheCheckTimeout;

/**
 Allows the application to override how cached files are named.
 By default, a generated unique file name based on the original file name will be used.
 */
@property (nonatomic, copy) IQCacheFileNaming cacheFileNaming;

/**
 Refreshes all cached items in this synchronized folder.
 If alwaysDownload is NO, checks with the server if the file has changed and only downloads files that have changed.
 If alwaysDownload is YES, redownloads all files regardless of if the changed status.
 */
- (void) refresh:(BOOL)alwaysDownload;

/**
 Adds a cache item.
 */
- (IQNetworkSynchronizedFile*) addFileWithURL:(NSURL*)url;

/**
 Blocks execution until all pending synchronization is complete.
 
 Avoid using this in a production application (see the doneHandler property instead).
 Blocking a thread wastes resources. This method is primarily intended to support unit testing.
 In addition, the implementation of this method is very inefficient.
 */
- (void) waitUntilSynchronized;
@end

typedef enum {
    /**
     If checked recently (see cacheCheckTimeout), uses the logic in IQSynchronizationUseCachedIfExists.
     Otherwise uses the logic in IQSynchronizationCheckModified.
     */
    IQSynchronizationDefault,
    /**
     Ask the server if the file has changed. If it has changed, download the new file before opening, otherwise use the cached file.
     If the server could not be reached, the cached version will be used, if available.
     */
    IQSynchronizationCheckModified,
    /**
     Always try to download the file, reagardless of the status of the cached file.
     If the server could not be reached, the cached version will be used, if available.
     */
    IQSynchronizationRefreshFile,
    /**
     Never try to download the file, reagardless of the status of the cached file.
     If the file is not in cache, it will be downloaded.
     */
    IQSynchronizationUseCachedIfExists,
    /**
     Never try to download the file, reagardless of the status of the cached file.
     If the file is not in cache, the open will fail.
     */
    IQSynchronizationUseCachedOrFail
} IQSynchronizationOptions;

@interface IQNetworkSynchronizedFile : NSObject

/**
 Synchronizes the file and returns the local path to the synchronized file.
 */
- (void) synchronize:(IQSynchronizedFileNameCallback)fileHandler errorHandler:(IQErrorHandler)errorHandler options:(IQSynchronizationOptions)options;

/**
 Synchronizes the file and opens a read handle to it.
 */
- (void) openForReading:(IQSynchronizedFileOpener)openHandler errorHandler:(IQErrorHandler)errorHandler options:(IQSynchronizationOptions)options;

@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic, readonly) NSDate* lastChecked;

/**
 Blocks execution until all pending synchronization is complete.
 
 Avoid using this in a production application (see the doneHandler property instead).
 Blocking a thread wastes resources. This method is primarily intended to support unit testing.
 In addition, the implementation of this method is very inefficient.
 */
- (void) waitUntilSynchronized;
/**
 Refreshes this cached item.
 If alwaysDownload is NO, checks with the server if the file has changed and only downloads files that have changed.
 If alwaysDownload is YES, redownloads all files regardless of if the changed status.
 
 Both completionHandler and errorHandler can be nil if the result of the refresh operation is not important.
 */
- (void) refresh:(BOOL)alwaysDownload completion:(IQGenericCallback)completionHandler errorHandler:(IQErrorHandler)errorHandler;

/**
 YES if the synchronized file is currently synchronizing.
 */
@property (atomic, readonly) BOOL isBusy;
@end