/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDigest.h"
#import <CommonCrypto/CommonDigest.h>

//File contents will be read in at 4096-byte chunks
#define BXDigestChunkSize 4096

@implementation BXDigest

+ (NSData *) SHA1DigestForFiles: (NSArray *)filePaths
{
	return [self SHA1DigestForFiles: filePaths upToLength: 0];
}

+ (NSData *) SHA1DigestForFiles: (NSArray *)filePaths upToLength: (NSUInteger)readLength
{
	CC_SHA1_CTX	context;
	
	NSMutableData *hash = [[NSMutableData alloc] initWithLength: CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1_Init(&context);
	
	for (NSString *filePath in filePaths)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSFileHandle *file		= [NSFileHandle fileHandleForReadingAtPath: filePath];
		
		NSData *chunk = nil;
		//Read the file in as chunks of BXDigestChunkSize length
		while ((chunk = [file readDataOfLength: BXDigestChunkSize]) && [chunk length])
		{
			CC_SHA1_Update(&context, [chunk bytes], [chunk length]);
			
			//Stop reading if we go over the desired length for this file 
			if (readLength && [file offsetInFile] >= readLength) break;
		}
			   
		[file closeFile];
		[pool release];
	}
	CC_SHA1_Final([hash mutableBytes], &context);
	
	return [hash autorelease];
}

@end