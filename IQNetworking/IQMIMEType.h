//
//  IQMIMEType.h
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-12-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IQMIMEType : NSObject <NSCopying, NSMutableCopying>
+ (id) MIMETypeWithMIMEType:(IQMIMEType*)other;
+ (id) MIMETypeWithRFCString:(NSString*)typeString;
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype;
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype parameters:(NSDictionary*)parameters;
+ (id) MIMETextTypeWithSubtype:(NSString*)subtype encoding:(NSStringEncoding)encoding;

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
