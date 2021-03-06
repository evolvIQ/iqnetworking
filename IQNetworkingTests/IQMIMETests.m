//
//  IQMIMETests.m
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

@interface IQNetworkingTests : XCTestCase
@end

@implementation IQNetworkingTests

- (void)testSimpleParsing
{
    IQMIMEType* mime = [IQMIMEType MIMETypeWithRFCString:@"text/plain"];
    XCTAssertEqualObjects(mime.type, @"text", @"Wrong MIME main type");
    XCTAssertEqualObjects(mime.subtype, @"plain", @"Wrong MIME subtype");
}

- (void)testSimpleGeneration
{
    IQMIMEType* mime = [IQMIMEType MIMETypeWithType:@"application" subtype:@"javascript"];
    XCTAssertEqualObjects(mime.type, @"application", @"Wrong MIME main type");
    XCTAssertEqualObjects(mime.subtype, @"javascript", @"Wrong MIME subtype");
    XCTAssertEqualObjects(mime.RFCString, @"application/javascript", @"Wrong MIME RFC string");
}

- (void)testCharsetParameter
{
    IQMutableMIMEType* mime = [IQMutableMIMEType MIMETypeWithRFCString:@"text/plain; charset=utf-8"];
    XCTAssertEqualObjects(mime.type, @"text", @"Wrong MIME main type");
    XCTAssertEqualObjects(mime.subtype, @"plain", @"Wrong MIME subtype");
    XCTAssertEqual((long)mime.encoding, (long)NSUTF8StringEncoding, @"Encoding was not UTF-8");
    mime.encoding = NSISOLatin1StringEncoding;
    XCTAssertEqualObjects(mime.RFCString, @"text/plain; charset=iso-8859-1", @"Wrong MIME RFC string");
}

- (void)testCharsets
{
    IQMIMEType* mime = [IQMIMEType MIMETypeWithRFCString:@"text/plain; charset=latin-1"];
    XCTAssertEqual((long)mime.encoding, (long)NSISOLatin1StringEncoding, @"Encoding was not latin-1");
    mime = [IQMIMEType MIMETypeWithRFCString:@"text/plain; charset=iso-8859-1"];
    XCTAssertEqual((long)mime.encoding, (long)NSISOLatin1StringEncoding, @"Encoding was not latin-1");
    mime = [IQMIMEType MIMETypeWithRFCString:@"text/plain; charset=iso-8859-2"];
    XCTAssertEqual((long)mime.encoding, (long)NSISOLatin2StringEncoding, @"Encoding was not latin-2");
    mime = [IQMIMEType MIMETypeWithRFCString:@"text/plain; charset=UTF-16"];
    XCTAssertEqual((long)mime.encoding, (long)NSUTF16StringEncoding, @"Encoding was not latin-2");
}

@end
