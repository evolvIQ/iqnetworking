//
//  IQTransferManager.m
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

#import "IQTransferManager.h"
#import "IQReachableStatus.h"
#import "IQMIMEType.h"

static NSMutableSet* activeTransferManagers = nil;

@interface IQTransferItem () {
@private
    IQTransferManager* manager;
    int statusCode;
    NSDictionary* responseHeaders;
    NSMutableURLRequest* request;
    BOOL started, done;
}
- (id) initWithURL:(NSURL*)url manager:(IQTransferManager*)mgr;
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
    NSMutableDictionary* defaultHeaders;
}

- (void)_transferCompleted:(IQTransferItem*)item;
- (void)_startTransfer:(IQTransferItem*)transfer;
- (void)_checkStart;
- (int)_maxConcurrent;
@end

@implementation IQTransferManager
@synthesize paused, ignoreErrorStatusCodes, timeoutInterval, followRedirects, doneHandler;

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

- (void) waitUntilEmpty
{
    while(true) {
        @synchronized(self) {
            if(queue.count == 0 && progress.count == 0) return;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (BOOL) isBusy
{
    @synchronized(self) {
        return !(queue.count == 0 && progress.count == 0);
    }
}

- (IQTransferItem*) postData:(NSData*)postData andDownloadProgressivelyFromURL:(NSURL*)url  handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)done errorHandler:(IQErrorHandler)errorHandler
{
    IQTransferItem* item = [self downloadDataProgressivelyFromURL:url handler:progressiveHandler done:done errorHandler:errorHandler];
    item.requestMethod = @"POST";
    item.requestBody = postData;
    return item;
}

- (IQTransferItem*) downloadDataProgressivelyFromURL:(NSURL*)url handler:(IQDataHandler)progressiveHandler done:(IQGenericCallback)done errorHandler:(IQErrorHandler)errorHandler
{
    IQTransferItem* item = [[IQTransferItem alloc] initWithURL:url manager:self];
    item.dataHandler = progressiveHandler;
    item.doneHandler = done;
    item.errorHandler = errorHandler;
    item.timeoutInterval = timeoutInterval;
    item.ignoreErrorStatusCodes = self.ignoreErrorStatusCodes;
    item.followRedirects = self.followRedirects;
    if(defaultHeaders) {
        for(NSString* key in defaultHeaders.keyEnumerator) {
            [item setValue:defaultHeaders[key] forRequestHeaderField:key];
        }
    }
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
        if(handler) {
            handler(data);
        }
    } errorHandler:errorHandler];
}

- (IQTransferItem*) postData:(NSData*)postData andDownloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler
{
    __block NSData* data = nil;
    __block BOOL isMutable = NO;
    return [self postData:postData andDownloadProgressivelyFromURL:url handler:^(NSData *result) {
        if(data == nil) {
            data = result;
        } else {
            if(!isMutable) data = [data mutableCopy];
            [(NSMutableData*)data appendData:result];
        }
        return YES;
    } done:^{
        if(handler) {
            handler(data);
        }
    } errorHandler:errorHandler];
}

- (IQTransferItem*) postForm:(NSDictionary*)formData andDownloadDataFromURL:(NSURL*)url handler:(IQResultHandler)handler errorHandler:(IQErrorHandler)errorHandler
{
    
    NSMutableString* postData = [[NSMutableString alloc] init];
    for(NSString* key in formData.keyEnumerator) {
        NSString* value = [[formData objectForKey:key] description];
        NSString* escapedValue = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)value, NULL, (CFStringRef)@"=&", kCFStringEncodingUTF8));
        if(postData.length > 0) [postData appendString:@"&"];
        [postData appendString:key];
        [postData appendString:@"="];
        [postData appendString:escapedValue];
    }
    NSLog(@"Posting %@", postData);
    NSData* rawdata = [postData dataUsingEncoding:NSUTF8StringEncoding];
    IQTransferItem* item = [self postData:rawdata andDownloadDataFromURL:url handler:handler errorHandler:errorHandler];
    item.postDataContentType = [IQMIMEType MIMETypeWithType:@"application" subtype:@"x-www-form-urlencoded"];
    return item;
}

- (IQTransferItem*) downloadFromURL:(NSURL*)url toFile:(NSFileHandle*)file done:(IQGenericCallback)done errorHandler:(IQErrorHandler)errorHandler
{
    return [self downloadDataProgressivelyFromURL:url handler:^(NSData *result) {
        @try {
            [file writeData:result];
            return YES;
        }
        @catch (NSException *exception) {
            if(errorHandler) {
                errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotWriteFileHandle userInfo:[NSDictionary dictionaryWithObject:[exception description] forKey:NSLocalizedDescriptionKey]]);
            }
            return NO;
        }
    } done:done errorHandler:errorHandler];
}

- (IQTransferItem*) downloadFromURL:(NSURL*)url toPath:(NSString*)path done:(IQGenericCallback)done errorHandler:(IQErrorHandler)errorHandler
{
    __block NSFileHandle* file = nil;
    return [self downloadDataProgressivelyFromURL:url handler:^(NSData *result) {
        if(!file) {
            file = [NSFileHandle fileHandleForWritingAtPath:path];
            if(!file) {
                if([[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
                    file = [NSFileHandle fileHandleForWritingAtPath:path];
                }
            }
            if(!file) {
                if(errorHandler) {
                    errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotOpenOutputFile userInfo:[NSDictionary dictionaryWithObject:@"Unable to open output file" forKey:NSLocalizedDescriptionKey]]);
                }
                return NO;
            }
        }
        @try {
            [file writeData:result];
            return YES;
        }
        @catch (NSException *exception) {
            if(errorHandler) {
                errorHandler([NSError errorWithDomain:kIQTransferManagerErrorDomain code:kIQTransferCannotWriteFileHandle userInfo:[NSDictionary dictionaryWithObject:[exception description] forKey:NSLocalizedDescriptionKey]]);
            }
            if(file) {
                [file closeFile];
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
            return NO;
        }
    } done:done errorHandler:^(NSError* err) {
        if(errorHandler) {
            errorHandler(err);
        }
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
        if(handler) {
            handler([[NSString alloc] initWithData:result encoding:enc]);
        }
    } errorHandler:errorHandler];
    return ret;
}

- (IQTransferItem*) downloadDictionaryFromURL:(NSURL*)url handler:(IQDictionaryHandler)handler format:(IQSerializationFormat)format errorHandler:(IQErrorHandler)errorHandler
{
    return [self downloadDataFromURL:url handler:^(NSData *result) {
        IQSerialization* ser = [IQSerialization new];
        NSDictionary* dict = [ser dictionaryFromData:result format:format];
        if(!dict) {
            if(errorHandler) {
                errorHandler(ser.error);
            }
        } else {
            if(handler) {
                handler(dict);
            }
        }
    } errorHandler:errorHandler];
}

- (IQTransferItem*) postObject:(id)object format:(IQSerializationFormat)postFormat andDownloadDictionaryFromURL:(NSURL*)url handler:(IQDictionaryHandler)handler format:(IQSerializationFormat)responseFormat errorHandler:(IQErrorHandler)errorHandler
{
    IQSerialization* ser = [IQSerialization new];
    NSData* postData = [ser serializeObject:object format:postFormat flags:IQSerializationFlagsDefault];
    if(!postData) {
        if(errorHandler) {
            errorHandler(ser.error);
        }
        return nil;
    }
    IQTransferItem* item = [self postData:postData andDownloadDataFromURL:url handler:^(NSData *result) {        
        NSDictionary* dict = [ser dictionaryFromData:result format:responseFormat];
        if(!dict) {
            if(errorHandler) {
                errorHandler(ser.error);
            }
        } else {
            if(handler) {
                handler(dict);
            }
        }
    } errorHandler:errorHandler];
    IQMIMEType* type = [IQMIMEType MIMETypeForSerializationFormat:postFormat];
    if(type) {
        [item setValue:type.RFCString forRequestHeaderField:@"Content-Type"];
    }
    return item;
}

- (void) setDefaultValue:(NSString*)value forRequestHeaderField:(NSString *)field
{
    if(defaultHeaders == nil && value) {
        defaultHeaders = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    if(!value) {
        [defaultHeaders removeObjectForKey:field];
    } else {
        [defaultHeaders setObject:value forKey:field];
    }
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
        [progress removeObject:item];
        [self _checkStart];
        if(progress.count == 0 && queue.count == 0 && doneHandler) {
            doneHandler();
        }
        [IQProgressAgregator progressChangedForObject:item];
    }
}

- (void)_startTransfer:(IQTransferItem*)item
{
    @synchronized(self) {
        [progress addObject:item];
        [item _start];
        [IQProgressAgregator progressChangedForObject:item];
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
@synthesize dataHandler, doneHandler, errorHandler, followRedirects;

- (id) initWithURL:(NSURL*)url manager:(IQTransferManager*)mgr
{
    self = [super init];
    if(self) {
        NSURLRequestCachePolicy cachePolicy = NSURLRequestUseProtocolCachePolicy;
        if(!mgr.ignoreCache) {
            cachePolicy = NSURLRequestReloadIgnoringCacheData;
        }
        request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:cachePolicy timeoutInterval:mgr.timeoutInterval];
        manager = mgr;
    }
    return self;
}

- (void)startImmediately
{
    [manager _startTransfer:self];
}

- (void)_start
{
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSURLConnection connectionWithRequest:request delegate:self];
        });
    } else {
        [NSURLConnection connectionWithRequest:request delegate:self];
    }
}

- (void) waitUntilDone
{
    while(true) {
        @synchronized(self) {
            if(done) return;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    statusCode = (int)response.statusCode;
    size = [[response.allHeaderFields objectForKey:@"Content-Length"] longLongValue];
    responseHeaders = response.allHeaderFields;
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

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)req redirectResponse:(NSURLResponse *)response
{
    if(followRedirects) {
        return req;
    } else {
        return nil;
    }    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    done = YES;
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
        if(errorHandler) {
            errorHandler(err);
        }
    } else {
        if(doneHandler) {
            doneHandler();
        }
    }
}

- (NSString*) valueForResponseHeaderField:(NSString*)field
{
    return [responseHeaders valueForKey:field];
}

- (NSString*) valueForRequestHeaderField:(NSString*)field
{
    return [request valueForHTTPHeaderField:field];
}

- (void) setValue:(NSString*)value forRequestHeaderField:(NSString *)field
{
    if(started) {
        [NSException raise:@"RequestAlreadySent" format:@"Cannot modify request headers, request is already sent"];
        return;
    }
    NSLog(@"Setting header field %@ to %@", field, value);
    [request setValue:value forHTTPHeaderField:field];
}

- (IQMIMEType*) contentType
{
    NSString* ct = [self valueForResponseHeaderField:@"Content-Type"];
    if(!ct) return nil;
    return [IQMIMEType MIMETypeWithRFCString:ct];
}

- (IQMIMEType*) postDataContentType
{
    NSString* ct = [self valueForRequestHeaderField:@"Content-Type"];
    if(!ct) return nil;
    return [IQMIMEType MIMETypeWithRFCString:ct];
}

- (void) setPostDataContentType:(IQMIMEType *)postDataContentType
{
    [self setValue:postDataContentType.RFCString forRequestHeaderField:@"Content-Type"];
}

#pragma mark - Properties

- (void) setTimeoutInterval:(NSTimeInterval)timeoutInterval
{
    if(started) {
        [NSException raise:@"RequestAlreadySent" format:@"Cannot modify request property, request is already sent"];
        return;
    }
    request.timeoutInterval = timeoutInterval;
}

- (NSTimeInterval) timeoutInterval
{
    return request.timeoutInterval;
}

- (void) setRequestBody:(NSData*)requestBody
{
    if(started) {
        [NSException raise:@"RequestAlreadySent" format:@"Cannot modify request property, request is already sent"];
        return;
    }
    request.HTTPBody = requestBody;
}

- (NSData*) requestBody
{
    return request.HTTPBody;
}

- (void) setRequestBodyStream:(NSInputStream *)requestBodyStream
{
    if(started) {
        [NSException raise:@"RequestAlreadySent" format:@"Cannot modify request property, request is already sent"];
        return;
    }
    request.HTTPBodyStream = requestBodyStream;
}

- (NSInputStream*) requestBodyStream
{
    return request.HTTPBodyStream;
}

- (void) setRequestMethod:(NSString *)requestMethod
{
    if(started) {
        [NSException raise:@"RequestAlreadySent" format:@"Cannot modify request property, request is already sent"];
        return;
    }
    request.HTTPMethod = requestMethod;
}

- (NSString*) requestMethod
{
    return request.HTTPMethod;
}

#pragma mark - IQProgressible

- (BOOL) isDone
{
    return done;
}

@end