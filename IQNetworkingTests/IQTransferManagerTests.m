//
//  IQTransferManagerTests.m
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

#import <XCTest/XCTest.h>

@interface IQTransferManagerTests : XCTestCase
@end

@implementation IQTransferManagerTests

- (void)testGetGoogleStartpage
{
    // This will be the URL to our server root
    NSURL* url = [NSURL URLWithString:@"http://www.google.com"];
    IQTransferManager* tm = [IQTransferManager new];
    
    IQTransferItem* item = [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTAssertTrue(string.length > 1024 && [string rangeOfString:@"<html"].length > 0, @"Unreasonable response from Google");
    } errorHandler:^(NSError *error) {
        XCTFail(@"HTTP request failed");
    }];
    
    [item waitUntilDone];
}

- (void)testGetMultipleRequests
{
    // This will be the URL to our server root
    NSURL* url = [NSURL URLWithString:@"http://www.google.com"];
    IQTransferManager* tm = [IQTransferManager new];
    
    __block int counter = 0;
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTAssertTrue(string.length > 1024 && [string rangeOfString:@"<html"].length > 0, @"Unreasonable response from Google");
        counter ++;
    } errorHandler:^(NSError *error) {
        XCTFail(@"HTTP request failed");
    }];
    
    [tm downloadStringFromURL:url handler:^(NSString *string) {
        XCTAssertTrue(string.length > 1024 && [string rangeOfString:@"<html"].length > 0, @"Unreasonable response from Google");
        counter ++;
    } errorHandler:^(NSError *error) {
        XCTFail(@"HTTP request failed");
    }];
    
    [tm waitUntilEmpty];
    
    XCTAssertEqual(2, counter, @"Expected 2 completed requests, but was %d", counter);
}

@end
