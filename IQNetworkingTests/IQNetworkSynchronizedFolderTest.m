//
//  IQNetworkSynchronizedFolderTest.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2013-09-28.
//  Copyright (c) 2013 EvolvIQ. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "IQHTTPServer.h"

@interface IQNetworkSynchronizedFolderTest : XCTestCase {
    IQHTTPServer* server;
}
@end

@implementation IQNetworkSynchronizedFolderTest

- (void)setUp
{
    server = [[IQHTTPServer alloc] init];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    int port = server.port;
    server.started = NO;
    XCTAssertTrue(port > 1024, @"Invalid port number %d", port);
}

- (void)tearDown
{
    [super tearDown];
    server = nil;
}

- (void)testServerWorks
{
    XCTAssertTrue(server.port > 1024, @"Server was not running");
}

@end
