//
//  IQNetworkSynchronizedFolder.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-11-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kIQNetworkSynchronizationErrorDomain @"kIQNetworkSynchronizationErrorDomain"

#define kIQNetworkSynchronizationErrorHandleAlreadyOpen -1001

@class IQNetworkSynchronizedFile;

@interface IQNetworkSynchronizedFolder : NSObject

+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name;
+ (IQNetworkSynchronizedFolder*)folderWithName:(NSString*)name inFolder:(IQNetworkSynchronizedFolder*)parent;

@end

@interface IQNetworkSynchronizedFile : NSObject
+ (IQNetworkSynchronizedFile*)fileWithLocalPath:(NSString*)path;
- (NSFileHandle*)syncFileHandleWithAtomic:(BOOL)atomic keepPreviousContent:(BOOL)keepPrevious error:(NSError**)error;
- (NSString*)path;
@end