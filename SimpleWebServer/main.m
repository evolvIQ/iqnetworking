//
//  main.c
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
#import <IQNetworking/IQNetworking.h>

int main(int argc, const char * argv[])
{
    IQHTTPServer* server = [[IQHTTPServer alloc] initWithPort:8001];
    //[server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@".+" options:0 error:nil] directory:@"."];
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/[^v]+" options:0 error:nil] callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        //NSLog(@"Got request :%@ %lld", request, request.requestBodyLength);
        if(request.requestBodyLength > 0) {
            //[request writeString:@"Hej POST!"];
            [request readRequestBody:^(IQHTTPServerRequest *request, NSData *data) {
                NSLog(@"Did read request body: %ld", data.length);
                [request writeString:[NSString stringWithFormat:@"Hej '%ld bytes'\r\n", data.length]];
                [request done];
            } atomic:YES];
        } else {
            [request writeString:@"Hej GET!"];
            [request done];
        }
    }];
    IQTransferManager* mgr = [[IQTransferManager alloc] init];
    [server addURLPattern:[NSRegularExpression regularExpressionWithPattern:@"/v" options:0 error:nil] callback:^(IQHTTPServerRequest *request, NSInteger sequence) {
        request.writeBufferLimit = 100*1024*1024;
        NSLog(@"Got request, starting download");
        [request setValue:[request valueForRequestHeaderField:@"Content-Type"] forResponseHeaderField:@"Content-Type"];
        [request setValue:[request valueForRequestHeaderField:@"Content-Length"] forResponseHeaderField:@"Content-Length"];
        [mgr downloadDataProgressivelyFromURL:[NSURL URLWithString:@"http://localhost:8000/api/link/prevex/video-main"] handler:^BOOL(NSData *data) {
            NSLog(@"Got data %ld", data.length);
            [request writeData:data];
            return YES;
        } done:^{
            NSLog(@"Done");
            [request done];
        } errorHandler:^(NSError *error) {
            NSLog(@"Error");
            [request done];
        }];
    }];
    server.started = YES;
    [[NSRunLoop currentRunLoop] run];
    return 0;
}

