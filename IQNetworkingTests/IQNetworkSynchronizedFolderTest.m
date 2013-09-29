//
//  IQNetworkSynchronizedFolderTest.m
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

#import <XCTest/XCTest.h>

#import "IQHTTPServer.h"
#import "IQTransferManager.h"
#import "IQNetworkSynchronizedFolder.h"

@interface IQNetworkSynchronizedFolderTest : XCTestCase {
    IQHTTPServer* server;
    NSString* testFolder;
    NSString* etag;
    NSString* hello;
    int serverRequests;
    int serverResponses;
}
@end

@implementation IQNetworkSynchronizedFolderTest

- (void)setUp
{
    hello = @"Hello, World!";
    etag = @"666";
    server = [[IQHTTPServer alloc] init];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    int port = server.port;
    XCTAssertTrue(port > 1024, @"Invalid port number %d", port);
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/hello_world\\.txt" options:NSRegularExpressionCaseInsensitive error:nil] callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        s->serverRequests ++;
        NSString* requestEtag = [request valueForRequestHeaderField:@"If-None-Match"];
        if(requestEtag && [requestEtag isEqualToString:s->etag]) {
            [request setStatusCode:304];
            [request done];
        } else {
            [request setValue:s->etag forResponseHeaderField:@"ETag"];
            [request writeString:s->hello];
            [request done];
            s->serverResponses ++;
        }
    }];
    for(int i = 1;; i++) {
        testFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"test_%04d", i]];
        if(![[NSFileManager defaultManager] fileExistsAtPath:testFolder]) {
            break;
        }
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:testFolder withIntermediateDirectories:YES attributes:nil error:nil];
}

- (NSURL*)URLForResource:(NSString*)resource
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/%@", server.port, resource]];
}

- (void)tearDown
{
    [super tearDown];
    server.started = NO;
    server = nil;
    if([[NSFileManager defaultManager] fileExistsAtPath:testFolder]) {
        NSError* err;
        if(![[NSFileManager defaultManager] removeItemAtPath:testFolder error:&err]) {
            NSLog(@"Failed to delete cache folder after unit test %@", testFolder);
        }
        if(err) {
            NSLog(@"%@", err);
        }
    }
}

- (void)testServerRespondsSanely
{
    XCTAssertTrue(server.port > 1024, @"Server was not running");
    IQTransferManager* manager = [[IQTransferManager alloc] init];
    
    XCTAssertEqual(0, serverRequests, @"Server request counter does not work");
    XCTAssertEqual(0, serverResponses, @"Server response counter does not work");
    
    __block IQTransferItem* item = nil;
    item = [manager downloadStringFromURL:[self URLForResource:@"hello_world.txt"] handler:^(NSString *string) {
        XCTAssertEqualObjects(hello, string, @"Unexpected HTTP response content");
        XCTAssertEqualObjects(etag, [item valueForResponseHeaderField:@"ETag"], @"Expected ETag value");
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download failed: %@", error);
    }];
    
    [manager waitUntilEmpty];
    item = nil;
    
    XCTAssertEqual(1, serverRequests, @"Server request counter does not work");
    XCTAssertEqual(1, serverResponses, @"Server response counter does not work");
}

- (void)testServerHandlesEtags
{
    XCTAssertTrue(server.port > 1024, @"Server was not running");
    IQTransferManager* manager = [[IQTransferManager alloc] init];
    
    __block IQTransferItem* item = nil;
    item = [manager downloadStringFromURL:[self URLForResource:@"hello_world.txt"] handler:^(NSString *string) {
        XCTFail(@"Expected a 304 response");
    } errorHandler:^(NSError *error) {
        XCTAssertEqual(304, (int)error.code, @"Expected a 304 status code");
    }];
    [item setValue:etag forRequestHeaderField:@"If-None-Match"];
    
    [manager waitUntilEmpty];
    item = nil;
    
    XCTAssertEqual(1, serverRequests, @"Expected one request");
    XCTAssertEqual(0, serverResponses, @"Expected no responses");
}

- (void)testCachedFileDownloads
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file is not correct");
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [folder waitUntilSynchronized];
    
    XCTAssertEqual(1, serverRequests, @"Expected request");
    XCTAssertEqual(1, serverResponses, @"Expected response");
}

- (void)testCacheOnlyDoesNotQueryServer
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block NSError* openError = nil;
    [file openForReading:^(NSFileHandle *handle) {
        XCTFail(@"The file should not have been opened");
    } errorHandler:^(NSError *error) {
        openError = error;
    } options:IQSynchronizationUseCachedOrFail];
    
    [file waitUntilSynchronized];
    
    XCTAssertNotNil(openError, @"Expected call to fail");
    XCTAssertEqualObjects(kIQNetworkSynchronizationErrorDomain, openError.domain, @"Expected error domain to be kIQNetworkSynchronizationErrorDomain");
    XCTAssertEqual(kIQNetworkSynchronizationErrorFileNotInCache, (int)openError.code, @"Expected error domain to be kIQNetworkSynchronizationErrorFileNotInCache");
    XCTAssertEqual(0, serverRequests, @"Expected no request");
    XCTAssertEqual(0, serverResponses, @"Expected no response");
    
}

- (void)testMultipleSimultaneousCacheOpensWithinTimeoutGivesOneRequest
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(1, serverRequests, @"Expected one request");
    XCTAssertEqual(1, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

- (void)testMultipleSequentialCacheOpensWithinTimeoutGivesOneRequest
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    folder.cacheCheckTimeout = 1e9;
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(1, serverRequests, @"Expected one request");
    XCTAssertEqual(1, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

- (void)testMultipleSequentialCacheOpensWithForceRefreshGivesTwoResponses
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationRefreshFile];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(2, serverRequests, @"Expected two requests");
    XCTAssertEqual(2, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

- (void)testMultipleSequentialCacheOpensAfterTimeoutGivesTwoRequests
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    folder.cacheCheckTimeout = 0;
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    usleep(10000);
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(2, serverRequests, @"Expected two requests");
    XCTAssertEqual(1, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

- (void)testMultipleSequentialCacheOpensWithoutTimeoutGivesTwoRequests
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    usleep(10000);
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationCheckModified];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(2, serverRequests, @"Expected two requests");
    XCTAssertEqual(1, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

- (void)testUseCachedVersionIfServerIsUnavailable
{
    IQNetworkSynchronizedFolder* folder = [IQNetworkSynchronizedFolder folderWithName:@"test" inParent:testFolder];
    
    IQNetworkSynchronizedFile* file = [folder addFileWithURL:[self URLForResource:@"hello_world.txt"]];
    
    __block BOOL completed1 = NO, completed2 = NO;
    
    __weak IQNetworkSynchronizedFolderTest* weakSelf = self;
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #1 is not correct");
        completed1 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #1 failed: %@", error);
    } options:IQSynchronizationDefault];
    
    [file waitUntilSynchronized];
    
    // Stop server
    server.started = NO;
    
    [file openForReading:^(NSFileHandle *handle) {
        IQNetworkSynchronizedFolderTest* s = weakSelf;
        NSString* string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(s->hello, string, @"Contents of synced file in op #2 is not correct");
        completed2 = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Download #2 failed: %@", error);
    } options:IQSynchronizationCheckModified];
    
    [file waitUntilSynchronized];
    
    XCTAssertEqual(1, serverRequests, @"Expected one request");
    XCTAssertEqual(1, serverResponses, @"Expected one response");
    
    XCTAssertTrue(completed1, @"Completion handler for #1 never called");
    XCTAssertTrue(completed2, @"Completion handler for #2 never called");
    
}

@end
