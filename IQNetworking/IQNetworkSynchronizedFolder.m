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
    IQTransferManager* transferManager;
}
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
        if(!globalTransferManager) {
            // Use the same transfer manager for all folders by default
            globalTransferManager = [[IQTransferManager alloc] init];
        }
        self->transferManager = globalTransferManager;
    }
    return self;
}

- (IQNetworkSynchronizedFile*) addFileWithURL:(NSURL*)url
{
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
        name = [NSString stringWithFormat:@"%@_%08x%@", fn, url.hash, ext];
    }
    IQNetworkSynchronizedFile* file = [[IQNetworkSynchronizedFile alloc] init];
}
@end

@interface IQNetworkSynchronizedFile () {
    NSString* path;
    NSFileHandle* syncFileHandle;
}

@end

@interface _IQNetworkSynchronizedFileHandle : NSFileHandle

@end

@implementation IQNetworkSynchronizedFile

+ (IQNetworkSynchronizedFile*)fileWithLocalPath:(NSString*)path
{
    IQNetworkSynchronizedFile* file = [[IQNetworkSynchronizedFile alloc] init];
    if(file) {
        file->path = path;
    }
    return file;
}

- (NSFileHandle*)syncFileHandleWithAtomic:(BOOL)atomic keepPreviousContent:(BOOL)keepPrevious error:(NSError**)error
{
    if(syncFileHandle != nil) {
        if(error) {
            *error = [NSError errorWithDomain:kIQNetworkSynchronizationErrorDomain code:kIQNetworkSynchronizationErrorHandleAlreadyOpen userInfo:[NSDictionary dictionaryWithObject:@"A synchronization handle is already open for this file." forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    NSFileManager* files = [NSFileManager defaultManager];
    if(atomic) {
        NSString* tempFilePath = [NSString stringWithFormat:@"%@sync\n%@.tmp", [path stringByDeletingLastPathComponent], [path lastPathComponent]];
        if(keepPrevious) {
            if(![files copyItemAtPath:path toPath:tempFilePath error:error]) {
                return nil;
            }
        }
    }
}

- (NSString*)path
{
    return path;
}
@end

@implementation _IQNetworkSynchronizedFileHandle

@end