//
//  IQNetworkSynchronizedFolder.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQNetworkSynchronizedFolder.h"

@implementation IQNetworkSynchronizedFolder

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