//
//  IQMIMEType.h
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

#import <Foundation/Foundation.h>
#import "IQSerialization.h"

@interface IQMIMEType : NSObject <NSCopying, NSMutableCopying>
+ (id) MIMETypeWithMIMEType:(IQMIMEType*)other;
+ (id) MIMETypeWithRFCString:(NSString*)typeString;
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype;
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype parameters:(NSDictionary*)parameters;
+ (id) MIMETextTypeWithSubtype:(NSString*)subtype encoding:(NSStringEncoding)encoding;

+ (id) MIMETypeForSerializationFormat:(IQSerializationFormat)format;

- (id) initWithRFCString:(NSString*)typeString;
- (id) initWithType:(NSString*)type subtype:(NSString*)subtype parameters:(NSDictionary*)parameters;


@property (nonatomic, readonly) NSString* type;
@property (nonatomic, readonly) NSString* subtype;
- (NSString*) valueForParameter:(NSString*)parameter;
- (NSStringEncoding) encoding;
- (NSString*) RFCString;
@end

@interface IQMutableMIMEType : IQMIMEType

@property (nonatomic, retain) NSString* type;
@property (nonatomic, retain) NSString* subtype;

- (void) setEncoding:(NSStringEncoding)encoding;

- (void) setValue:(NSString*)value forParameter:(NSString*)parameter;
- (void) removeParameter:(NSString*)parameter;

@end
