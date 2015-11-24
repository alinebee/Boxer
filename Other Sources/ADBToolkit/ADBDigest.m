/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBDigest.h"
#import <CommonCrypto/CommonDigest.h>

//File contents will be read in at 4096-byte chunks
#define ADBDigestChunkSize 4096

@implementation ADBDigest

+ (NSData *) SHA1DigestForURLs: (NSArray *)fileURLs error: (out NSError **)outError
{
	return [self SHA1DigestForURLs: fileURLs upToLength: 0 error: outError];
}

+ (NSData *) SHA1DigestForURLs: (NSArray *)fileURLs upToLength: (NSUInteger)readLength error: (out NSError **)outError
{
	CC_SHA1_CTX	context;
	
	NSMutableData *hash = [[NSMutableData alloc] initWithLength: CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1_Init(&context);
	
	for (NSURL *fileURL in fileURLs)
	@autoreleasepool {
		NSFileHandle *file		= [NSFileHandle fileHandleForReadingFromURL: fileURL error: outError];
        
        //If there was an error opening the file, bail out.
        if (!file)
        {
            return nil;
		}
        
		NSData *chunk = nil;
		//Read the file in as chunks of ADBDigestChunkSize length
		while ((chunk = [file readDataOfLength: ADBDigestChunkSize]) && chunk.length)
		{
			CC_SHA1_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
			
			//Stop reading if we go over the desired length for this file 
			if (readLength && file.offsetInFile >= readLength) break;
		}
			   
		[file closeFile];
	}
	CC_SHA1_Final(hash.mutableBytes, &context);
	
	return hash;
}

@end
