//
//  IQDownloadManager.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQTransferManager.h"
#import "IQReachableStatus.h"
#import "IQMIMEType.h"

static NSMutableSet* activeTransferManagers = nil;

@interface IQTransferItem () {
@private
    NSURL* url;
    IQTransferManager* manager;
    int statusCode;
    NSDictionary* headers;
}
+ (IQTransferItem*)_transferItemWithUrl:(NSURL*)url manager:(IQTransferManager*)manager;
- (void)_start;

@property (nonatomic, copy) IQDataHandler dataHandler;
@property (nonatomic, copy) IQGenericCallback doneHandler;
@property (nonatomic, copy) IQErrorHandler errorHandler;
@property (nonatomic, readonly) long long size;
@property (nonatomic, readonly) long long progress;
@property (nonatomic) NSTimeInterval timeoutInterval;
@end

@interface IQTransferManager () {
    NSMutableArray* queue;
    NSMutableSet* progress;
}

- (void)_transferCompleted:(IQTransferItem*)item;
- (void)_startTransfer:(IQTransferItem*)transfer;
- (void)_checkStart;
- (int)_maxConcurrent;
@end

@implementation IQTransferManager
@synthesize paused, ignoreErrorStatusCodes, timeoutInterval, followRedirects;

- (id) init
{
    self = [super init];
    if(self) {
        queue = [NSMutableArray arrayWithCapacity:4];
        progress = [NSMutableSet set];
        timeoutInterval = 10.0;
        ignoreErrorStatusCodes = NO;
        followRedirects = YES;
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"Deallocing IQTransferManager");
}

- (void) waitUntilEmpty
{
    while(true) {
        @synchronized(self) {
            if(queue.count == 0 && progress.count == 0) return;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (IQTransferItem*) downloadDataProgressivelyFromURL:(NSURL*)url handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler
{
    IQTransferItem* item = [IQTransferItem _transferItemWithUrl:url manager:self];
    item.dataHandler = progressiveHandler;
    item.doneHandler = doneHandler;
    item.errorHandler = errorHandler;
    item.timeoutInterval = timeoutInterval;
    item.ignoreErrorStatusCodes = self.ignoreErrorStatusCodes;
    item.followRedirects = self.followRedirects;
    @synchronized(self) {
        [queue addObject:item];
        if(activeTransferManagers == nil) {
            activeTransferManagers = [NSMutableSet setWithCapacity:1];
        }
        [activeTransferManagers addObject:self];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _checkStart];
    });
    return item;
}

- (IQTransferItem*) downloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler
{
    __block NSData* data = nil;
    __block BOOL isMutable = NO;
    return [self downloadDataProgressivelyFromURL:url handler:^(NSData *result) {
        if(data == nil) {
            data = result;
        } else {
            if(!isMutable) data = [data mutableCopy];
            [(NSMutableData*)data appendData:result];
        }
        return YES;
    } done:^{
        handler(data);
    } errorHandler:errorHandler];
}

- (IQTransferItem*) downloadFromURL:(NSURL*)url toFile:(NSFileHandle*)file done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler
{
    return [self downloadDataProgressivelyFromURL:url handler:^(NSData *result) {
        @try {
            [file writeData:result];
            return YES;
        }
        @catch (NSException *exception) {
            errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotWriteFileHandle userInfo:[NSDictionary dictionaryWithObject:[exception description] forKey:NSLocalizedDescriptionKey]]);
            return NO;
        }
    } done:^{
        doneHandler();
    } errorHandler:errorHandler];
}

- (IQTransferItem*) downloadFromURL:(NSURL*)url toPath:(NSString*)path done:(IQGenericCallback)doneHandler errorHandler:(IQErrorHandler)errorHandler
{
    __block NSFileHandle* file = nil;
    return [self downloadDataProgressivelyFromURL:url handler:^(NSData *result) {
        if(!file) file = [NSFileHandle fileHandleForWritingAtPath:path];
        if(!file) {
            errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotOpenOutputFile userInfo:[NSDictionary dictionaryWithObject:@"Unable to open output file" forKey:NSLocalizedDescriptionKey]]);
            return NO;
        }
        @try {
            [file writeData:result];
            return YES;
        }
        @catch (NSException *exception) {
            errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotWriteFileHandle userInfo:[NSDictionary dictionaryWithObject:[exception description] forKey:NSLocalizedDescriptionKey]]);
            if(file) {
                [file closeFile];
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
            return NO;
        }
    } done:^{
        doneHandler();
    } errorHandler:^(NSError* err) {
        errorHandler(err);
        if(file) {
            [file closeFile];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
    }];
}

- (IQTransferItem*) downloadStringFromURL:(NSURL*)url handler:(IQStringHandler)handler errorHandler:(IQErrorHandler)errorHandler
{
    __block IQTransferItem* ret = nil;
    ret = [self downloadDataFromURL:url handler:^(NSData *result) {
        IQMIMEType* mt = ret.contentType;
        NSStringEncoding enc = NSUTF8StringEncoding;
        if(mt) {
            enc = mt.encoding;
            if(!enc) enc = NSISOLatin1StringEncoding;
        }
        handler([[NSString alloc] initWithData:result encoding:enc]);
    } errorHandler:errorHandler];
    return ret;
}

- (IQTransferItem*) downloadDictionaryFromURL:(NSURL*)url handler:(IQDictionaryHandler)handler format:(IQSerializationFormat)format errorHandler:(IQErrorHandler)errorHandler
{
    return [self downloadDataFromURL:url handler:^(NSData *result) {
        IQSerialization* ser = [IQSerialization new];
        NSDictionary* dict = [ser dictionaryFromData:result format:format];
        if(!dict) {
            errorHandler(ser.error);
        } else {
            handler(dict);
        }
    } errorHandler:errorHandler];
}

#pragma mark - Internal methods

- (int)_maxConcurrent
{
    if([IQReachableStatus currentReachability] == IQNetworkWiFi) {
        return 6;
    } else {
        return 3;
    }
}

- (void)_checkStart
{
    @synchronized(self) {
        while(queue.count > 0 && progress.count < [self _maxConcurrent]) {
            IQTransferItem* item = [queue objectAtIndex:0];
            [queue removeObjectAtIndex:0];
            [self _startTransfer:item];
        }
        if(!queue.count) {
            [activeTransferManagers removeObject:self];
        }
    }
}

- (void)_transferCompleted:(IQTransferItem*)item
{
    @synchronized(self) {
        NSLog(@"Transfer completed");
        [progress removeObject:item];
        [self _checkStart];
    }
}

- (void)_startTransfer:(IQTransferItem*)transfer
{
    @synchronized(self) {
        NSLog(@"Starting transfer");
        [progress addObject:transfer];
        [transfer _start];
    }
}

- (void)setPaused:(BOOL)newPaused
{
    if(paused && !newPaused) {
        paused = newPaused;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _checkStart];
        });
    } else {
        paused = newPaused;
    }
}
@end

@implementation IQTransferItem
@synthesize size, progress, ignoreErrorStatusCodes;
@synthesize dataHandler, doneHandler, errorHandler, timeoutInterval, followRedirects;

+ (IQTransferItem*)_transferItemWithUrl:(NSURL*)url manager:(IQTransferManager*)manager
{
    IQTransferItem* transfer = [[IQTransferItem alloc] init];
    if(transfer) {
        transfer->url = url;
        transfer->manager = manager;
    }
    return transfer;
}

- (void)startImmediately
{
    [manager _startTransfer:self];
}

- (void)_start
{
    NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:self.timeoutInterval];
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSURLConnection connectionWithRequest:request delegate:self];
        });
    } else {
        [NSURLConnection connectionWithRequest:request delegate:self];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    statusCode = (int)response.statusCode;
    size = [[response.allHeaderFields objectForKey:@"Content-Length"] longLongValue];
    headers = response.allHeaderFields;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if(!dataHandler(data)) {
        [connection cancel];
    }
    progress += data.length;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [manager _transferCompleted:self];
    errorHandler(error);
    [connection cancel];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if(followRedirects) {
        return request;
    } else {
        return nil;
    }    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [manager _transferCompleted:self];
    if(!ignoreErrorStatusCodes && statusCode != 200) {
        NSString* str = nil;
        switch(statusCode) {
            case 401:
                str = NSLocalizedString(@"Authentication required.", @"HTTP err");
                break;
            case 403:
                str = NSLocalizedString(@"You are not authorized to perform this operation.", @"HTTP err");
                break;
            case 404:
                str = NSLocalizedString(@"Remote resource was not found.", @"HTTP err");
                break;
            case 500:
                str = NSLocalizedString(@"The server experiences temporary problems.", @"HTTP err");
                break;
            case 501:
                str = NSLocalizedString(@"The request is not supported by the server.", @"HTTP err");
                break;
            default:
                str = [NSString stringWithFormat:@"Error #%d", statusCode];
        }
        NSError* err = [NSError errorWithDomain:kIQTransferManagerErrorDomain code:statusCode userInfo:[NSDictionary dictionaryWithObject:str forKey:NSLocalizedDescriptionKey]];
        errorHandler(err);
    } else {
        doneHandler();
    }
}

- (NSString*) valueForResponseHeaderField:(NSString*)field
{
    return [headers valueForKey:field];
}

- (IQMIMEType*) contentType
{
    NSString* ct = [self valueForResponseHeaderField:@"Content-Type"];
    if(!ct) return nil;
    return [IQMIMEType MIMETypeWithRFCString:ct];
}

@end