/*

File: NSURLLoader.m

Abstract: CFNetwork ImageClient Sample

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (c) 2005 Apple Computer, Inc., All Rights Reserved

*/ 

#import "NSURLLoader.h"
#import "ImageClient.h"
#import "CFNetworkLoader.h"


@implementation NSURLLoader
- (id)initWithImageClient:(ImageClient *)imgClient {
    if (self = [super init]) {
        imageClient = imgClient; // No retain because the ImageClient instance is retaining us
    }
    return self;
}

- (void) dealloc {
    [self cancelLoad];
    [url release];
    [super dealloc];
}

- (void)loadURL:(NSURL *)theURL {
    // Cancel any load currently in progress
    [self cancelLoad];
    
    // Create an empty data to receive bytes from the download
    data = [[NSMutableData alloc] init];

    if (url) [url release];
    url = theURL;
    [url retain];

    // Start the download
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)cancelLoad {
    if (connection) {
        [connection cancel];
        [connection release];
        connection = nil;
    }
    if (data) {
        [data release];
        data = nil;
    }
    if (challenge) {
        [challenge release];
        challenge = nil;
    }
}

/* NSURLConnection delegate methods */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newData {
    [data appendData:newData];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [imageClient setImageData:data];
    [self cancelLoad]; // This shuts down the connection for us
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    CFNetDiagnosticRef diagnostics = CFNetDiagnosticCreateWithURL(NULL, (CFURLRef)url);
    [imageClient errorOccurredLoadingImage:diagnostics];
    [self cancelLoad]; // This shuts down the connection for us
}

/* Called when the connection receives a challenge from the server */
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)newChallenge {

    if (challenge) [challenge release];
    challenge = newChallenge;
    [challenge retain];

    NSURLProtectionSpace *space = [challenge protectionSpace];
    [imageClient authorizationNeededForRealm: [space realm] onHost: [space host] isProxy: [space isProxy]];
}

- (void)resumeWithCredentials {
    // Grab the username and password from imageClient and apply them to the challenge
    NSString *user = [imageClient username];
    NSString *pass = [imageClient password];
    
    // Guarantee values
    if (!user) user = @"";
    if (!pass) pass = @"";

	NSURLCredentialPersistence persistence = NSURLCredentialPersistenceForSession;
	if ([imageClient saveCredentials])
        persistence = NSURLCredentialPersistencePermanent;
		
	NSURLCredential *creds = [NSURLCredential credentialWithUser:user password:pass persistence: persistence];
    [[challenge sender] useCredential:creds forAuthenticationChallenge:challenge];
    
    [challenge release];
    challenge = nil;
}


/* Called when a connection waiting for user/pass is cancelled, so that we can clean up any lingering state */
- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self cancelLoad];
}

@end
