//
//  IQMIMEType.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-12-28.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQMIMEType.h"

@interface IQMIMEType () {
@public
    NSString* type;
    NSString* subtype;
    NSDictionary* parameters;
}

- (BOOL) _parseString:(NSString*)string;
- (void) _setParameters:(NSDictionary*)parameters;
@end

@implementation IQMIMEType
@synthesize type, subtype;
+ (id) MIMETypeWithMIMEType:(IQMIMEType*)other
{
    return [other copy];
}
+ (id) MIMETypeWithRFCString:(NSString*)typeString
{
    return [[IQMIMEType alloc] initWithRFCString:typeString];
}
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype
{
    return [IQMIMEType MIMETypeWithType:type subtype:subtype parameters:nil];
}
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype parameters:(NSDictionary*)parameters
{
    return [[IQMIMEType alloc] initWithType:type subtype:subtype parameters:parameters];
}
+ (id) MIMETextTypeWithSubtype:(NSString*)subtype encoding:(NSStringEncoding)encoding
{
    return [[IQMutableMIMEType MIMETextTypeWithSubtype:subtype encoding:encoding] copy];
}

- (id) initWithRFCString:(NSString*)typeString
{
    self = [super init];
    if(self) {
        if(![self _parseString:typeString]) {
            return nil;
        }
    }
    return self;
    
}
- (id) initWithType:(NSString*)t subtype:(NSString*)st parameters:(NSDictionary*)p
{
    self = [super init];
    if(self) {
        type = t;
        subtype = st;
        [self _setParameters:p];
    }
    return self;
}

- (BOOL) _parseString:(NSString*)string
{
    int i = 0;
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!string.length) return NO;
    NSString* tt, *st;
    NSMutableDictionary* params = nil;
    for(NSString* chunk in [string componentsSeparatedByString:@";"]) {
        if(i == 0) {
            NSArray* t = [chunk componentsSeparatedByString:@"/"];
            if(t.count != 2) return NO;
            tt = [[[t objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
            st = [[[t objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
            if(!tt.length || !st.length) return NO;
        } else {
            NSArray* t = [chunk componentsSeparatedByString:@"="];
            if(t.count != 2) return NO;
            if(!params) params = [NSMutableDictionary dictionary];
            NSString* pk = [[[t objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
            NSString* pv = [[t objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if(!pk.length || !pv.length) return NO;
            [params setValue:pv forKey:pk];
        }
        i++;
    }
    type = tt;
    subtype = st;
    [self _setParameters:params];
    return YES;
}

- (void) _setParameters:(NSDictionary *)p
{
    parameters = [p copy];
}

- (NSString*) valueForParameter:(NSString*)parameter
{
    return [self->parameters objectForKey:parameter];
}

- (NSStringEncoding) encoding
{
    NSString* charset = [self valueForParameter:@"charset"];
    if(charset && charset.length) {
        return CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset));
    }
    return 0;
}

- (NSString*) RFCString
{
    NSString* tv = [NSString stringWithFormat:@"%@/%@", type, subtype];
    if(!parameters || !parameters.count) return tv;
    NSMutableString* c = [NSMutableString new];
    for(NSString* param in [parameters keyEnumerator]) {
        [c appendString:@"; "];
        [c appendString:param];
        [c appendString:@"="];
        [c appendString:parameters[param]];
    }
    return [tv stringByAppendingString:c];
}

- (id) copy
{
    return [self copyWithZone:nil];
}

- (id) mutableCopy
{
    return [self mutableCopyWithZone:nil];
}

- (id) copyWithZone:(NSZone *)zone
{
    IQMIMEType* mime = [IQMIMEType allocWithZone:zone];
    mime->type = type;
    mime->subtype = subtype;
    [mime _setParameters:parameters];
    return mime;
}

- (id) mutableCopyWithZone:(NSZone *)zone
{
    IQMutableMIMEType* mime = [IQMutableMIMEType allocWithZone:zone];
    mime->type = type;
    mime->subtype = subtype;
    [mime _setParameters:parameters];
    return mime;
    
}

@end

@implementation IQMutableMIMEType

- (void) _setParameters:(NSDictionary *)p
{
    parameters = [p mutableCopy];
}
   + (id) MIMETypeWithMIMEType:(IQMIMEType*)other
{
    IQMutableMIMEType* mime = [[IQMutableMIMEType alloc] init];
    mime->type = other->type;
    mime->subtype = other->subtype;
    [mime _setParameters:other->parameters];
    return mime;
}
+ (id) MIMETypeWithRFCString:(NSString*)typeString
{
    return [[IQMutableMIMEType alloc] initWithRFCString:typeString];
}
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype
{
    return [IQMutableMIMEType MIMETypeWithType:type subtype:subtype parameters:nil];
}
+ (id) MIMETypeWithType:(NSString*)type subtype:(NSString*)subtype parameters:(NSDictionary*)parameters
{
    IQMutableMIMEType* mime = [[IQMutableMIMEType alloc] init];
    if(!mime) {
        return nil;
    }
    mime->type = type;
    mime->subtype = subtype;
    [mime _setParameters:parameters];
    return mime;
}
+ (id) MIMETextTypeWithSubtype:(NSString*)subtype encoding:(NSStringEncoding)encoding
{
    IQMutableMIMEType* mime = [[IQMutableMIMEType alloc] init];
    if(!mime) {
        return nil;
    }
    mime->type = @"text";
    if(!subtype.length) subtype = @"plain";
    mime->subtype = subtype;
    mime.encoding = encoding;
    return mime;
}

- (void) setType:(NSString *)t
{
    self->type = t;
}

- (void) setSubtype:(NSString *)st
{
    self->subtype = st;
}

- (void) removeParameter:(NSString*)parameter
{
    [(NSMutableDictionary*)self->parameters removeObjectForKey:parameter];
}

- (void) setValue:(NSString *)value forParameter:(NSString *)parameter
{
    if(!parameters) parameters = [NSMutableDictionary dictionary];
    [(NSMutableDictionary*)self->parameters setObject:value forKey:parameter];
}

- (void) setEncoding:(NSStringEncoding)encoding
{
    if(encoding == 0) {
        [self removeParameter:@"charset"];
    } else {
        CFStringEncoding enc = CFStringConvertNSStringEncodingToEncoding(encoding);
        NSString* str = objc_unretainedObject(CFStringConvertEncodingToIANACharSetName(enc));
        [self setValue:str forParameter:@"charset"];
    }
}

@end
