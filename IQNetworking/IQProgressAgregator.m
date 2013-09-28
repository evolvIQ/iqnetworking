//
//  IQProgressAgregator.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2013-01-22.
//  Copyright (c) 2013 EvolvIQ. All rights reserved.
//

#import "IQProgressAgregator.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static IQProgressAgregator* globalAggregator = nil;
@interface IQProgressAgregator () {
    NSMapTable* progressObjects;
}
@end
@interface _IQProgressibleReference : NSObject {
@public
    long long totalBytes, bytesDone;
    BOOL done;
    __weak id<IQProgressible> object;
}
- (id) initWithProgressible:(id<IQProgressible>)progressible;
- (void) update;
@end

@implementation IQProgressAgregator

+ (IQProgressAgregator*) globalAggregator
{
    if(!globalAggregator) {
        globalAggregator = [[IQProgressAgregator alloc] init];
    }
    return globalAggregator;
}

+ (void) progressChangedForObject:(id<IQProgressible>)object
{
    if(globalAggregator) {
        [globalAggregator addProgressible:object];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIQProgressibleProgressChanged object:object];
}

- (void) addProgressible:(id<IQProgressible>)object
{
    if(!progressObjects) {
        progressObjects = [NSMapTable weakToStrongObjectsMapTable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receivedProgressUpdate:) name:kIQProgressibleProgressChanged object:nil];
    }
    _IQProgressibleReference* pref = [[_IQProgressibleReference alloc] initWithProgressible:object];
    [progressObjects setObject:pref forKey:object];
    [self _updateProgressible:pref];
}

- (void) _updateProgressible:(_IQProgressibleReference*)pref
{
    [pref update];
    if(pref->done) {
        [progressObjects removeObjectForKey:pref->object];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIQProgressAggregatorProgressChanged object:self];
#if TARGET_OS_IPHONE
    if(_manageNetworkIndicator) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:self.working];
    }
#endif
}

- (void) _receivedProgressUpdate:(NSNotification*)notification
{
    _IQProgressibleReference* pref = [progressObjects objectForKey:notification.object];
    if(pref) {
        [self _updateProgressible:pref];
    }
}

- (BOOL) working
{
    return progressObjects.count > 0;
}

- (long long) totalBytes
{
    long long tb = 0;
    for(_IQProgressibleReference* pref in progressObjects) {
        tb += pref->totalBytes;
    }
    return tb;
}

- (long long) bytesDone
{
    long long bd = 0;
    for(_IQProgressibleReference* pref in progressObjects) {
        bd += pref->bytesDone;
    }
    return bd;
}

@end

@implementation _IQProgressibleReference

- (id) initWithProgressible:(id<IQProgressible>)progressible
{
    self = [super init];
    if(self) {
        self->object = progressible;
    }
    return self;
}

- (void) update
{
    done = [object isDone];
    if([object respondsToSelector:@selector(bytesDone)] && [object respondsToSelector:@selector(totalBytes)]) {
        totalBytes = [object totalBytes];
        bytesDone = [object bytesDone];
    }
}

@end