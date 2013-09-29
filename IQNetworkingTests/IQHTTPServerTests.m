//
//  IQHTTPServerTests.m
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

#import "IQNetworking.h"

#import <XCTest/XCTest.h>

@interface IQHTTPServerTests : XCTestCase
@end

@implementation IQHTTPServerTests

- (void)testListenSpecificPort
{
    IQHTTPServer* server = [[IQHTTPServer alloc] initWithPort:12345];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    int port = server.port;
    server.started = NO;
    XCTAssertEqual(port, 12345, @"Wrong port number");
}

- (void)testListenRandomPort
{
    IQHTTPServer* server = [[IQHTTPServer alloc] init];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    int port = server.port;
    server.started = NO;
    XCTAssertTrue(port > 1024, @"Invalid port number %d", port);
}

- (void)testReleasingPort
{
    IQHTTPServer* server1 = [[IQHTTPServer alloc] initWithPort:12345];
    IQHTTPServer* server2 = [[IQHTTPServer alloc] initWithPort:12345];
    server1.started = YES;
    XCTAssertTrue(server1.started, @"Server 1 failed to start");
    server2.started = YES; // Should fail
    XCTAssertFalse(server2.started, @"Server 2 did start despite occupied port");
    server1.started = NO;
    server2.started = YES;
    XCTAssertTrue(server2.started, @"Server 2 failed to start");
}

- (void)testServeNothing
{
    // Create an empty HTTP server. Empty HTTP servers are pretty useless, all they serve are 404 responses...
    IQHTTPServer* server = [[IQHTTPServer alloc] init];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    
    // This will be the URL to our server root
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/", server.port]];
    IQTransferManager* tm = [IQTransferManager new];
    
    __block BOOL done = NO;
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        done = YES;
        XCTFail(@"Request should not have succeeded");
    } errorHandler:^(NSError *error) {
        done = YES;
        NSLog(@"Hej %@", error);
        XCTAssertEqual((int)error.code, (int)404, @"Expected HTTP error 404");
    }];
    
    [tm waitUntilEmpty];
    server.started = NO;
}

- (void)testServeString
{
    // Create a simple HTTP server that returns the plain string 'wörld' (with an umlaut to test charsets)§ for requests on '/hello'
    IQHTTPServer* server = [[IQHTTPServer alloc] init];
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/hello" options:0 error:nil] callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        [request writeString:@"wörld"];
        [request done];
    }];
    server.started = YES;
    XCTAssertTrue(server.started, @"Server failed to start");
    
    // This will be the URL to our service
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/hello", server.port]]; 
    
    IQTransferManager* tm = [IQTransferManager new];
    
    
    __block BOOL done = NO;
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTAssertEqualObjects(string, @"wörld", @"Expected 'wörld'");
        NSLog(@"Succeeded: %@", string);
        done = YES;
    } errorHandler:^(NSError *error) {
        XCTFail(@"Failed with error %@", error);
        done = YES;
    }];
    
    [tm waitUntilEmpty];
    server.started = NO;
}

- (void)testServeWithParam
{
    // Create a simple HTTP server that returns the URL parameter in the response
    IQHTTPServer* server = [IQHTTPServer new];
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/hello/([0-9]+)" options:0 error:nil] callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        [request writeString:[NSString stringWithFormat:@"The answer to the ultimate question is %@", [request valueForUrlPatternGroup:1]]];
        [request done];
    }];
    server.started = YES;
    
    XCTAssertTrue(server.started, @"Server failed to start");
    
    IQTransferManager* tm = [IQTransferManager new];
    
    // No parameter, expect 404
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/hello", server.port]];
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTFail(@"Expected 404 error");
    } errorHandler:^(NSError *error) {
        XCTAssertEqual(404, (int)error.code, @"Expected 404 error");
    }];
    
    [tm waitUntilEmpty];
    
    // Not a number, expect 404
    url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/hello/A", server.port]];
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTFail(@"Expected 404 error");
    } errorHandler:^(NSError *error) {
        XCTAssertEqual(404, (int)error.code, @"Expected 404 error");
    }];
    
    [tm waitUntilEmpty];
    
    // Expect the number to be used in the repsonse
    url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/hello/42", server.port]];
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTAssertEqualObjects(@"The answer to the ultimate question is 42", string, @"Expected the answer to be 42");
    } errorHandler:^(NSError *error) {
        XCTFail(@"Failed with error %@", error);
    }];
    
    [tm waitUntilEmpty];
    
    server.started = NO;
}

@end
