//
//  IQHTTPServer.m
//  IQNetworking
//
//  Created by Rickard Petzäll on 2012-12-27.
//  Copyright (c) 2012 EvolvIQ. All rights reserved.
//

#import "IQHTTPServer.h"
#import "IQMIMEType.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>

@interface IQHTTPServer () {
@public
    CFSocketRef serverSocket;
    NSRunLoop* actualRunLoop;
    NSMutableSet* connections;
    NSMutableArray* urlPatterns;
}
@end

@interface _IQHTTPURLHandler : NSObject
@property (nonatomic, retain) NSRegularExpression* regexp;
@property (nonatomic, copy) IQHTTPRequestCallback callback;
@end

@interface _IQHTTPServerConnection : NSObject {
@public
    CFSocketNativeHandle socket;
    NSInputStream* input;
    NSOutputStream* output;
    IQHTTPServerRequest* currentRequest;
    IQHTTPServer* server;
    BOOL keepAlive;
    NSMutableData* backBuffer;
    CFHTTPMessageRef dispatchOnOpen;
}

- (id) initWithSocket:(CFSocketNativeHandle)socket runLoop:(NSRunLoop*)runLoop server:(IQHTTPServer*)server;
- (void) close;
@property (nonatomic, readonly) BOOL isIdle;
@end

@interface IQHTTPServerRequest () {
    CFSocketNativeHandle socket;
    _IQHTTPServerConnection* connection;
    CFHTTPMessageRef requestHeaders, responseHeaders;
    long long remainingBody;
    long long contentLength;
    BOOL headerWasComplete;
    IQHTTPRequestReader bodyReader;
    BOOL readBodyAtomic;
    NSMutableData* requestBodyBuffer;
    BOOL headersSent;
    NSStringEncoding encoding;
    BOOL didSetContentType;
    NSMutableData* writeBuffer;
    IQHTTPRequestCallback currentCallback;
    NSInteger seq;
    BOOL isDone;
}

- (id) initWithConnection:(_IQHTTPServerConnection*)connection;
- (void) _readRequest;
- (void) _sendHeaders;
- (void) _dispatchRequest:(CFHTTPMessageRef)msg;
- (void) _handleRequest;
@end

@implementation IQHTTPServer
@synthesize port, address, runLoop, callback, keepAliveTimeout, writeBufferLimit;

- (id) init
{
    return [self initWithPort:0];
}

- (id) initWithPort:(UInt16)p
{
    return [self initWithAddress:nil port:p];
}
- (id) initWithAddress:(NSString*)a port:(UInt16)p
{
    self = [super init];
    if(self) {
        self->writeBufferLimit = 1024*1024;
        self->port = p;
        self->address = a;
        self->connections = [NSMutableSet setWithCapacity:120];
    }
    return self;
}

static void ListenSocketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    NSLog(@"ACCEPT");
    CFSocketNativeHandle peerSocket = *(CFSocketNativeHandle *)data;
    IQHTTPServer* server = (__bridge IQHTTPServer*)info;
    _IQHTTPServerConnection* connection = [[_IQHTTPServerConnection alloc] initWithSocket:peerSocket runLoop:server->actualRunLoop server:server];
    [server->connections addObject:connection];
}

- (NSData*) _addressIPV4:(NSString*)a port:(UInt16)p
{
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(p);
    
    if(!a) {
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
    } else {
        if(1 != inet_pton(AF_INET, [a UTF8String], &addr.sin_addr)) {
            return nil;
        }
    }
    
    return [NSData dataWithBytes: &addr length:sizeof(addr)];
}

- (NSData*) _addressIPV6:(NSString*)a port:(UInt16)p
{
    struct sockaddr_in6 addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin6_len = sizeof(addr);
    addr.sin6_family = AF_INET6;
    addr.sin6_port = htons(p);
    
    if(!a) {
        addr.sin6_addr = in6addr_any;
    } else {
        if(1 != inet_pton(AF_INET6, [a UTF8String], &addr.sin6_addr)) {
            return nil;
        }
    }
    
    return [NSData dataWithBytes: &addr length:sizeof(addr)];
}

- (void) setStarted:(BOOL)newStarted
{
    if(newStarted && !serverSocket) {
        CFSocketContext ctx = {0, (__bridge void *)(self), 0, 0, 0};
        serverSocket = CFSocketCreate(kCFAllocatorDefault, 0, 0, 0, kCFSocketAcceptCallBack, ListenSocketCallback, &ctx);
        if(!serverSocket) {
            return;
        }
        
        int value = 1;
        setsockopt(CFSocketGetNative(serverSocket), SOL_SOCKET, SO_REUSEADDR, (void *)&value, sizeof(int));
        
        NSData* addr = [self _addressIPV4:address port:port];
        if(!addr) {
            addr = [self _addressIPV6:address port:port];
            if(!addr) {
                NSLog(@"Failed to get the local address to bind to");
                CFRelease(serverSocket);
                serverSocket = nil;
                return;
            }
        }
        
        if (CFSocketSetAddress(serverSocket, (__bridge CFDataRef)addr) != kCFSocketSuccess) {
            NSLog(@"Failed to bind to address");
            CFRelease(serverSocket);
            serverSocket = nil;
            return;
        }
        
        CFDataRef data = CFSocketCopyAddress(serverSocket);
        struct sockaddr_in* sa = (struct sockaddr_in*)CFDataGetBytePtr(data);
        if(sa->sin_len >= sizeof(struct sockaddr_in)) {
            port = ntohs(sa->sin_port);
        }
        CFRelease(data);

        CFRunLoopSourceRef runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocket, 1);
        actualRunLoop = runLoop ? runLoop : [NSRunLoop currentRunLoop];
        CFRunLoopAddSource([actualRunLoop getCFRunLoop], runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
    } else if(!newStarted && serverSocket) {
        [self closeAllConnectionsForce:NO];
        CFSocketInvalidate(serverSocket);
        CFRelease(serverSocket);
        serverSocket = nil;
    }
}

- (void) closeAllConnectionsForce:(BOOL)force
{
    for(_IQHTTPServerConnection* connection in connections) {
        if(force || connection.isIdle) {
            [connection close];
        }
    }
}

- (BOOL) started
{
    return serverSocket != nil;
}

- (void) dealloc
{
    self.started = NO;
}

- (void) setRunLoop:(NSRunLoop*)rl
{
    BOOL wasStarted = self.started;
    if(wasStarted) {
        self.started = NO;
    }
    runLoop = rl;
    if(wasStarted) {
        self.started = YES;
    }
}

- (void) setPort:(UInt16)p
{
    BOOL wasStarted = self.started;
    if(wasStarted) {
        self.started = NO;
    }
    self->port = p;
    if(wasStarted) {
        self.started = YES;
    }
    
}

- (void) setAddress:(NSString *)a
{
    BOOL wasStarted = self.started;
    if(wasStarted) {
        self.started = NO;
    }
    self->address = a;
    if(wasStarted) {
        self.started = YES;
    }
}

- (void) addURLPattern:(NSRegularExpression*)pattern callback:(IQHTTPRequestCallback)cb
{
    if(pattern == nil) {
        NSLog(@"Warning: nil URL pattern -- ignoring");
        return;
    }
    if(!urlPatterns) {
        urlPatterns = [NSMutableArray array];
    }
    _IQHTTPURLHandler* uh = [[_IQHTTPURLHandler alloc] init];
    uh.regexp = pattern;
    uh.callback = cb;
    [urlPatterns addObject:uh];
}
- (void) addURLPattern:(NSRegularExpression*)pattern directory:(NSString*)staticFileDirectory
{
    [self addURLPattern:pattern callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        //
    }];
}

@end

@implementation _IQHTTPServerConnection


- (id) initWithSocket:(CFSocketNativeHandle)sock runLoop:(NSRunLoop*)rl server:(IQHTTPServer*)srv
{
    self = [super init];
    if(self) {
        CFReadStreamRef readStream = nil;
        CFWriteStreamRef writeStream = nil;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
        input = objc_unretainedObject(readStream);
        output = objc_unretainedObject(writeStream);
        input.delegate = (id<NSStreamDelegate>)self;
        output.delegate = (id<NSStreamDelegate>)self;
        [input scheduleInRunLoop:rl forMode:NSRunLoopCommonModes];
        [output scheduleInRunLoop:rl forMode:NSRunLoopCommonModes];
        [input open];
        [output open];
        socket = sock;
        server = srv;
    }
    return self;
}

- (void) dealloc
{
    if(socket) {
        close(socket);
        socket = 0;
    }
}

- (void) close
{
    currentRequest = nil;
    [input close];
    [output close];
    if(socket) {
        close(socket);
        socket = 0;
    }
    input = nil;
    output = nil;
    [server->connections removeObject:self];
}

- (BOOL) isIdle
{
    return (currentRequest == nil);
}

- (void) _requestDone
{
    currentRequest = nil;
    if(!keepAlive) [self close];
}

- (void) _requestRead
{
    if(!keepAlive) [input close];
}


- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if(aStream == input) {
        switch(eventCode) {
            case NSStreamEventHasBytesAvailable:
                if(currentRequest == nil) {
                    currentRequest = [[IQHTTPServerRequest alloc] initWithConnection:self];
                }
                [currentRequest _readRequest];
                break;
            case NSStreamEventEndEncountered:
                break;
            case NSStreamEventErrorOccurred:
                NSLog(@"Read error");
                break;
            default:
                break;
        }
    } else if(aStream == output) {
        //NSLog(@"Output event, %d", (int)eventCode);
        switch(eventCode) {
            case NSStreamEventHasSpaceAvailable:
                if(dispatchOnOpen) {
                    [self->currentRequest _dispatchRequest:dispatchOnOpen];
                    CFRelease(dispatchOnOpen);
                    dispatchOnOpen = nil;
                } else if(self->currentRequest) {
                    [self->currentRequest _handleRequest];
                }
                break;
            case NSStreamEventEndEncountered:
                break;
            case NSStreamEventErrorOccurred:
                NSLog(@"Write error");
                break;
            default:
                break;
        }
    }
}

@end

@implementation IQHTTPServerRequest
@synthesize statusCode, writeBufferLimit;

- (id) initWithConnection:(_IQHTTPServerConnection*)conn
{
    self = [super init];
    if(self) {
        connection = conn;
        writeBufferLimit = conn->server.writeBufferLimit;
        encoding = NSUTF8StringEncoding; // Default to UTF-8 (We always write encoding type explicitly)
    }
    return self;
}

- (void) dealloc
{
    if(requestHeaders) {
        CFRelease(requestHeaders);
        requestHeaders = nil;
    }
    if(responseHeaders) {
        CFRelease(responseHeaders);
        responseHeaders = nil;
    }
}

- (void) _dispatchRequest:(CFHTTPMessageRef)msg
{
    if(!connection->output.hasSpaceAvailable) {
        connection->dispatchOnOpen = (CFHTTPMessageRef)CFRetain(msg);
        return;
    }
    NSURL* url = objc_unretainedObject(CFHTTPMessageCopyRequestURL(msg));
    NSString* resourceSpecifier = url.resourceSpecifier;
    NSRange sr = NSMakeRange(0, resourceSpecifier.length);
    
    self->currentCallback = nil;
    
    BOOL hasMatch = NO;
    if(!resourceSpecifier) {
        NSLog(@"Bad request");
        self.statusCode = 400;
        [self done];
        return;
    }
    for(_IQHTTPURLHandler* handler in self.server->urlPatterns) {
        NSRange range = [handler.regexp rangeOfFirstMatchInString:resourceSpecifier options:NSMatchingAnchored range:sr];
        if(range.location == 0 && range.length == resourceSpecifier.length) {
            hasMatch = YES;
            self->currentCallback = handler.callback;
            break;
        }
    }
    if(!hasMatch) {
        if(self.server.callback) {
            self->currentCallback = self.server.callback;
        } else {
            self.writeBufferLimit = 1024;
            self.statusCode = 404;
            [self setValue:@"text/plain" forResponseHeaderField:@"Content-Type"];
            [self writeString:@"The file was not found"];
            [self done];
            return;
        }
    }
    [self _handleRequest];
}

- (BOOL) _drainBuffers
{
    if(writeBuffer.length > 0) {
        NSInteger written = [connection->output write:writeBuffer.bytes maxLength:writeBuffer.length];
        if(written < 0) {
            [self cancel];
            return NO;
        } else if(written == writeBuffer.length) {
            [writeBuffer setLength:0];
            if(writeBufferLimit == 0) {
                writeBuffer = nil; // No longer needed
            }
            return YES;
        } else if(written > 0) {
            NSInteger newLength = writeBuffer.length - written;
            [writeBuffer replaceBytesInRange:NSMakeRange(0, newLength) withBytes:(char*)writeBuffer.bytes+written];
            return NO;
        }
    }
    return YES;
}

- (void) _handleRequest
{
    if(isDone) {
        if(connection->currentRequest == self) {
            [connection _requestDone];
        }
        return;
    }
    if(self.hasSpaceAvailable) {
        // Drain any buffer first
        if(![self _drainBuffers]) {
            // Buffer draining choked the output stream for now.
            return;
        }
        if(seq == 0 || writeBufferLimit == 0) {
            // Callback is called at least once, but may be called subsequently if buffering is turned off
            // Disabling buffering introduces more complexity at the application level, but reduces the memory
            // use and buffer copies so in some cases it may be useful (such as when serving static content from
            // application memory or files).
            self->currentCallback(self, seq++);
        }
    }
}

- (void) _readChunk:(UInt8*)buf length:(CFIndex)len
{
    UInt8* sbuf = NULL;
    sbuf = buf;
    while(sbuf < buf+len) {
        UInt8* nsbuf = NULL;
        if(!headerWasComplete) {
            // Read header line-by-line to allow pipelined requests
            nsbuf = memchr(sbuf, '\n', len-(sbuf-buf));
            if(nsbuf) nsbuf++;
        }
        if(!nsbuf) {
            nsbuf = buf + len;
        }
        if(!headerWasComplete) {
            if(!CFHTTPMessageAppendBytes(requestHeaders, sbuf, nsbuf-sbuf)) {
                NSLog(@"Unable to append bytes to message");
                [self cancel];
                return;
            }
            BOOL hc = CFHTTPMessageIsHeaderComplete(requestHeaders);
            if(hc) {
                headerWasComplete = YES;
                CFStringRef str = CFHTTPMessageCopyHeaderFieldValue(requestHeaders, (__bridge CFStringRef)@"Content-Length");
                if(str) {
                    remainingBody = [(__bridge NSString*)str longLongValue];
                    contentLength = remainingBody;
                    CFRelease(str);
                }
                [self _dispatchRequest:requestHeaders];
            }
        } else {
            if(remainingBody > 0) {
                UInt8* endptr = nsbuf;
                if(remainingBody < nsbuf-sbuf) {
                    endptr = sbuf + remainingBody;
                }
                remainingBody -= endptr - sbuf;
                if((readBodyAtomic && remainingBody > 0) || !bodyReader) {
                    if(!requestBodyBuffer) {
                        requestBodyBuffer = [NSMutableData dataWithCapacity:endptr-sbuf];
                    }
                    [requestBodyBuffer appendBytes:sbuf length:endptr-sbuf];
                } else if(requestBodyBuffer.length > 0) {
                    [requestBodyBuffer appendBytes:sbuf length:endptr-sbuf];
                    bodyReader(self, requestBodyBuffer);
                    requestBodyBuffer = nil;
                } else {
                    bodyReader(self, [NSData dataWithBytes:sbuf length:endptr-sbuf]);
                }
                if(remainingBody == 0) {
                    if(endptr < buf + len) {
                        if(!connection->backBuffer) {
                            connection->backBuffer = [NSMutableData dataWithCapacity:buf+len-endptr];
                        }
                        [connection->backBuffer appendBytes:endptr length:buf+len-endptr];
                        break;
                    }
                    if(connection->currentRequest == self) {
                        [connection _requestRead];
                    }
                }
            }
        }
        sbuf = nsbuf;
    }

}
- (NSString*) valueForRequestHeaderField:(NSString*)field
{
    return objc_retainedObject(CFHTTPMessageCopyHeaderFieldValue(requestHeaders, (__bridge CFStringRef)field));
}
- (NSString*) valueForResponseHeaderField:(NSString*)field
{
    return objc_retainedObject(CFHTTPMessageCopyHeaderFieldValue(responseHeaders, (__bridge CFStringRef)field));
}

- (void) _readRequest
{
    IQHTTPServerRequest* keepSelf = self;
    if(!requestHeaders) {
        requestHeaders = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
        remainingBody = 0LL;
    }
    if(connection->backBuffer) {
        [self _readChunk:(UInt8*)connection->backBuffer.bytes length:connection->backBuffer.length];
    }
    while(connection->input.hasBytesAvailable) {
        UInt8 buf[512];
        CFIndex len = [connection->input read:buf maxLength:sizeof(buf)];
        if(len < 0) {
            [self cancel];
            return;
        }
        if(len > 0) {
            [self _readChunk:buf length:len];
        }
    }
    keepSelf = nil;
}

- (IQHTTPServer*) server
{
    return connection->server;
}

- (void) readRequestBody:(IQHTTPRequestReader)reader atomic:(BOOL)atomic
{
    if(bodyReader) {
        [NSException raise:@"MultipleReadsOnBody" format:@"Only one readRequestBody:atomic: call per requst is allowed"];
        return;
    }
    bodyReader = reader;
    readBodyAtomic = atomic;
    if(bodyReader && (remainingBody == 0 || !readBodyAtomic) && requestBodyBuffer.length > 0) {
        bodyReader(self, requestBodyBuffer);
        requestBodyBuffer = nil;
    }
}

- (long long) requestBodyLength
{
    return contentLength;
}

#pragma mark - Response

- (void) cancel
{
    isDone = YES;
    if(connection->currentRequest == self) {
        [connection _requestDone];
    }
}

- (void) done
{
    isDone = YES;
    [self _sendHeaders];
    if(self.hasSpaceAvailable && [self _drainBuffers]) {
        if(connection->currentRequest == self) {
            [connection _requestDone];
        }
    }
}

- (void) setStatusCode:(NSInteger)sc
{
    if(headersSent || responseHeaders) {
        [NSException raise:@"ReadOnlyAtThisTime" format:@"Cannot set statusCode at this stage"];
        return;
    }
    if(sc < 0 || sc >= 600) statusCode = 500;
    self->statusCode = sc;
}

- (NSInteger) statusCode
{
    if(statusCode == 0) return 200;
    return statusCode;
}

- (void) _initHeaders
{
    if(!responseHeaders) {
        responseHeaders = CFHTTPMessageCreateResponse(kCFAllocatorDefault, self.statusCode, NULL, kCFHTTPVersion1_1);
    }
}

- (void) setValue:(NSString*)value forResponseHeaderField:(NSString *)field
{
    if(headersSent || isDone) {
        [NSException raise:@"HeadersAlreadySent" format:@"Headers are already sent. Cannot modify headers at this time."];
        return;
    }
    [self _initHeaders];
    if([value isEqualToString:@"Content-Type"]) {
        IQMutableMIMEType* mime = [IQMutableMIMEType MIMETypeWithRFCString:value];
        NSStringEncoding enc = mime.encoding;
        if(enc == 0) {
            if([mime.type isEqualToString:@"text"]) {
                mime.encoding = self->encoding;
                value = [mime RFCString];
            }
        } else {
            self->encoding = enc;
        }
        didSetContentType = YES;
    }
    CFHTTPMessageSetHeaderFieldValue(responseHeaders, (__bridge CFStringRef)field, (__bridge CFStringRef)value);
}

- (void) _sendHeaders
{
    if(!headersSent) {
        [self _initHeaders];
        // Check encoding
        if(!didSetContentType) {
            IQMutableMIMEType* mime = [IQMutableMIMEType MIMETextTypeWithSubtype:@"plain" encoding:encoding];
            CFHTTPMessageSetHeaderFieldValue(responseHeaders, (__bridge CFStringRef)@"Content-Type", (__bridge CFStringRef)[mime RFCString]);
        }
        NSData* headerBuffer = (__bridge NSData *)(CFHTTPMessageCopySerializedMessage(responseHeaders));
        if(writeBuffer.length > 0) [NSException raise:@"InvalidHeaderState" format:@"Header buffer not empty"];
        writeBuffer = [NSMutableData dataWithData:headerBuffer];
        headersSent = YES;
        CFRelease(responseHeaders);
        responseHeaders = nil;
    }
}

- (void)writeString:(NSString*)string
{
    [self writeData:[string dataUsingEncoding:encoding allowLossyConversion:YES]];
}

- (NSInteger)writeData:(NSData*)data
{
    return [self write:data.bytes maxLength:data.length];
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len
{
    NSInteger written = 0;
    [self _sendHeaders];
    
    if(writeBuffer && writeBufferLimit == 0) {
        if(!self.hasSpaceAvailable) return written;
        if(![self _drainBuffers]) return written;
    }
    if(self.hasSpaceAvailable && writeBuffer.length == 0) {
        written = [connection->output write:buffer maxLength:len];
        if(written < 0) {
            [self cancel];
            return 0;
        }
    }
    if(written == len || writeBufferLimit == 0) return written;
    
    // Did not fit in socket buffer. Try to buffer in the request object instead.
    NSInteger remainingCapacity = writeBufferLimit-writeBuffer.length;
    if(remainingCapacity < len-written) {
        [NSException raise:@"BufferOverrun" format:@"The application has overrun the write buffer limit for the connection. Limit throughput on the application side."];
    } else {
        if(!writeBuffer) writeBuffer = [NSMutableData dataWithCapacity:len-written];
        [writeBuffer appendBytes:buffer+written length:len-written];
        if(self.hasSpaceAvailable) {
            [self _drainBuffers];
        }
    }
    return len;
}

- (BOOL) hasSpaceAvailable
{
    if(connection->currentRequest != self) return NO;
    return connection->output.hasSpaceAvailable;
}

@end

@implementation _IQHTTPURLHandler
@synthesize regexp, callback;
@end