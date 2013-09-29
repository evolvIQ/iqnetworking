//
//  IQNetworkSynchronizedFolder.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQNetworkSynchronizedFolder.h"
#import "IQTransferManager.h"

static IQTransferManager* globalTransferManager = nil;

@interface IQNetworkSynchronizedFolder () {
    NSMutableArray* files;
@public
    IQTransferManager* transferManager;
}
- (NSString*) _pathForItem:(NSString*)name;
@end

@interface IQNetworkSynchronizedFile() {
    int refreshCount;
}
+ (IQNetworkSynchronizedFile*)_fileWithURL:(NSURL*)url localName:(NSString*)name inFolder:(IQNetworkSynchronizedFolder*)folder;
+ (IQNetworkSynchronizedFile*)_fileWithDictionary:(NSDictionary*)dictionary inFolder:(IQNetworkSynchronizedFolder*)folder;
- (NSDictionary*) _dictionary;
@end

@implementation IQNetworkSynchronizedFolder
+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name inParent:(NSString*)path
{
    return [[IQNetworkSynchronizedFolder alloc] initWithName:name parent:path];
}
+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name
{
    NSString* parent = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [[IQNetworkSynchronizedFolder alloc] initWithName:name parent:parent];
}

- (id)initWithName:(NSString*)name parent:(NSString*)parent
{
    self = [super init];
    if(self) {
        self->_name = name;
        self->_localPath = [parent stringByAppendingPathComponent:name];
        self->_cacheCheckTimeout = 3600.0;
        [self _loadState];
        if(!globalTransferManager) {
            // Use the same transfer manager for all folders by default
            globalTransferManager = [[IQTransferManager alloc] init];
        }
        self->transferManager = globalTransferManager;
    }
    return self;
}

- (void)_loadState
{
    if([[NSFileManager defaultManager] fileExistsAtPath:self->_localPath isDirectory:YES]) {
        NSString* dictPath = [self->_localPath stringByAppendingPathComponent:@".syncstate"];
        NSArray* syncState = [NSArray arrayWithContentsOfFile:dictPath];
        if(syncState != nil) {
            files = [NSMutableArray arrayWithCapacity:syncState.count];
            for(NSDictionary* file in syncState) {
                IQNetworkSynchronizedFile* f = [IQNetworkSynchronizedFile _fileWithDictionary:file inFolder:self];
                if(f) {
                    [files addObject:f];
                }
            }
        } else {
            NSLog(@"Unable to read sync state");
        }
    }
    if(files == nil) {
        files = [NSMutableArray array];
    }
}

- (void)_ensureLocaldir
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:self->_localPath]) {
        NSError* err;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:self->_localPath withIntermediateDirectories:YES attributes:nil error:&err]) {
            NSLog(@"Unable to create cache dir: %@", err);
        }
    }
 }

- (void)_saveState
{
    @synchronized(files) {
        NSMutableArray* array = [NSMutableArray arrayWithCapacity:files.count];
        for(IQNetworkSynchronizedFile* file in files) {
            NSDictionary* dict = [file _dictionary];
            if(dict) {
                [array addObject:dict];
            }
        }
        [self _ensureLocaldir];
        NSString* dictPath = [self->_localPath stringByAppendingPathComponent:@".syncstate"];
        if(![array writeToFile:dictPath atomically:NO]) {
            NSLog(@"Unable to save sync state");
        }
    }
}

- (IQNetworkSynchronizedFile*) addFileWithURL:(NSURL*)url
{
    @synchronized(files) {
        for(IQNetworkSynchronizedFile* file in self->files) {
            if([file.url isEqual:url]) {
                return file;
            }
        }
        NSString* name = nil;
        if(_cacheFileNaming) {
            name = _cacheFileNaming(url);
        }
        if(name == nil) {
            NSString* fn = url.lastPathComponent;
            NSString* ext = @"";
            if(fn.length == 0) {
                fn = url.host;
            } else {
                ext = fn.pathExtension,
                fn = fn.stringByDeletingPathExtension;
            }
            if(fn.length == 0) {
                fn = @"untitled";
            }
            if(ext.length > 0) {
                ext = [@"." stringByAppendingString:ext];
            }
            name = [NSString stringWithFormat:@"%@_%08lx%@", fn, (unsigned long)url.hash, ext];
        }
        NSString* localPath = [_localPath stringByAppendingPathComponent:name];
        NSLog(@"Local Path: %@", localPath);
        IQNetworkSynchronizedFile* file = [IQNetworkSynchronizedFile _fileWithURL:url localName:name inFolder:self];
        [self->files addObject:file];
        [self _saveState];
        return file;
    }
}
- (void) refresh:(BOOL)alwaysDownload
{
    for(IQNetworkSynchronizedFile* file in files) {
        [file refresh:alwaysDownload completion:nil errorHandler:nil];
    }
}

- (NSString*) _pathForItem:(NSString*)name
{
    return [self->_localPath stringByAppendingPathComponent:name];
}

- (void) waitUntilSynchronized
{
    while(true) {
        @synchronized(self) {
            BOOL anyBusy = NO;
            for(IQNetworkSynchronizedFile* file in files) {
                anyBusy |= file.isBusy;
            }
            if(!anyBusy) break;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}
@end

@interface IQNetworkSynchronizedFile () {
    __weak IQNetworkSynchronizedFolder* folder;
    NSURL* url;
    NSString* name;
    NSString* etag;
    NSString* tempFile;
    IQTransferItem* syncItem;
}

@end

@implementation IQNetworkSynchronizedFile

+ (IQNetworkSynchronizedFile*)_fileWithURL:(NSURL*)url localName:(NSString*)name inFolder:(IQNetworkSynchronizedFolder*)folder
{
    IQNetworkSynchronizedFile* file = [[IQNetworkSynchronizedFile alloc] init];
    if(file) {
        file->folder = folder;
        file->url = url;
        file->name = name;
    }
    return file;
}

+ (IQNetworkSynchronizedFile*)_fileWithDictionary:(NSDictionary*)dictionary inFolder:(IQNetworkSynchronizedFolder*)folder
{
    IQNetworkSynchronizedFile* file = [[IQNetworkSynchronizedFile alloc] init];
    if(file) {
        file->folder = folder;
        file->url = [NSURL URLWithString:dictionary[@"url"]];
        file->name = dictionary[@"name"];
        file->etag = dictionary[@"etag"];
        if(file->url == nil || file->name == nil) {
            // Bad record?
            return nil;
        }
    }
    return file;
}

- (void) openForReading:(IQSynchronizedFileOpener)openHandler errorHandler:(IQErrorHandler)errorHandler options:(IQSynchronizationOptions)options
{
    NSString* path = self.path;
    BOOL wasDefault = NO;
    if(options == IQSynchronizationDefault) {
        wasDefault = YES;
        if(_lastChecked == nil || [_lastChecked timeIntervalSinceNow] < -folder.cacheCheckTimeout) {
            options = IQSynchronizationCheckModified;
        } else {
            options = IQSynchronizationUseCachedIfExists;
        }
    }
    // Try to open the existing file if allowed
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSFileHandle* handle;
        switch(options) {
            case IQSynchronizationUseCachedOrFail:
            case IQSynchronizationUseCachedIfExists:
                // File exists, just open it since we don't care if its outdated
                handle = [NSFileHandle fileHandleForReadingAtPath:path];
                break;
            default:
                handle = nil;
                break;
        }
        if(handle) {
            if(openHandler) {
                openHandler(handle);
            }
            return;
        }
    }
    if(options == IQSynchronizationUseCachedOrFail) {
        if(errorHandler) {
            errorHandler([NSError errorWithDomain:kIQNetworkSynchronizationErrorDomain code:kIQNetworkSynchronizationErrorFileNotInCache userInfo:[NSDictionary dictionaryWithObject:@"File is not in cache" forKey:NSLocalizedDescriptionKey]]);
        }
        return;
    }
    
    dispatch_queue_t q = dispatch_get_current_queue();
    
    if(syncItem != nil && !syncItem.isDone) {
        NSLog(@"sync is blocked by a previous request");
        __block id observer = nil;
        [[NSNotificationCenter defaultCenter] addObserverForName:kIQProgressibleProgressChanged object:syncItem queue:nil usingBlock:^(NSNotification *note) {
            if(syncItem == nil || syncItem.isDone) {
                dispatch_async(q, ^{
                    NSLog(@"sync is now un-blocked");
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                    [self openForReading:openHandler errorHandler:errorHandler options:wasDefault?IQSynchronizationDefault:options];
                });
            }
        }];
    } else {
        BOOL alwaysDownload;
        switch(options) {
            case IQSynchronizationCheckModified:
            case IQSynchronizationUseCachedIfExists:
                alwaysDownload = NO;
                break;
            case IQSynchronizationRefreshFile:
                alwaysDownload = YES;
                break;
            default:
                return;
        }
        [self refresh:alwaysDownload completion:^{
            NSLog(@"I have now downloaded myself");
            [self openForReading:openHandler errorHandler:errorHandler options:IQSynchronizationUseCachedOrFail];
        } errorHandler:errorHandler];
    }
    
}

- (void) waitUntilSynchronized
{
    while(true) {
        @synchronized(self) {
            if(syncItem == nil || syncItem.isDone) return;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (BOOL) isBusy
{
    return syncItem != nil && !syncItem.isDone;
}

- (void) refresh:(BOOL)alwaysDownload completion:(IQGenericCallback)completionHandler errorHandler:(IQErrorHandler)errorHandler
{
    @synchronized(self) {
        [folder _ensureLocaldir];
        refreshCount ++;
        tempFile = [self.path stringByAppendingString:[NSString stringWithFormat:@".%d.download", refreshCount]];
        __weak IQNetworkSynchronizedFile* weakSelf = self;
        __block IQTransferItem* item = nil;
        item = [folder->transferManager downloadFromURL:url toPath:tempFile done:^{
            IQNetworkSynchronizedFile* s = weakSelf;
            if(item && s && s->syncItem == item) {
                // The request is recent
                s->syncItem = nil;
                NSError* error = nil;
                if([[NSFileManager defaultManager] fileExistsAtPath:s.path]) {
                    [[NSFileManager defaultManager] removeItemAtPath:s.path error:&error];
                }
                if(!error) {
                    [[NSFileManager defaultManager] moveItemAtPath:s->tempFile toPath:s.path error:&error];
                }
                if(error) {
                    if(errorHandler) {
                        errorHandler(error);
                    }
                } else {
                    s->_lastChecked = [NSDate date];
                    s->etag = [item valueForResponseHeaderField:@"ETag"];
                    [s->folder _saveState];
                    if(completionHandler) {
                        completionHandler();
                    }
                }
            }
        } errorHandler:^(NSError* error) {
            IQNetworkSynchronizedFile* s = weakSelf;
            if(item && s && s->syncItem == item) {
                s->syncItem = nil;
            }
            if([error.domain isEqualToString:kIQTransferManagerErrorDomain] && error.code == 304) {
                s->_lastChecked = [NSDate date];
                [s->folder _saveState];
                if(completionHandler) {
                    completionHandler();
                }
            } else {
                if(errorHandler) {
                    errorHandler(error);
                }
            }
        }];
        if(etag && !alwaysDownload) {
            [item setValue:etag forRequestHeaderField:@"If-None-Match"];
        }
        syncItem = item;
    }
}

- (NSString*)path
{
    return [folder _pathForItem:name];
}

- (NSURL*)url
{
    return url;
}

- (NSDictionary*)_dictionary
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    if(name) dict[@"name"] = name;
    if(url) dict[@"url"] = [url absoluteString];
    if(etag) dict[@"etag"] = etag;
    return dict;
}
@end
