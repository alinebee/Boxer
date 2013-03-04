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


#import "ADBFileTransferSet.h"
#import "ADBSingleFileTransfer.h"


#pragma mark -
#pragma mark Implementation

@implementation ADBFileTransferSet
@synthesize copyFiles = _copyFiles;

#pragma mark -
#pragma mark Initialization and deallocation

+ (id) transferForPaths: (NSDictionary *)paths
			  copyFiles: (BOOL)copy
{
	return [[[self alloc] initForPaths: paths copyFiles: copy] autorelease];
}

- (id) initForPaths: (NSDictionary *)paths copyFiles: (BOOL)copy
{
	if ((self = [self init]))
	{
        self.copyFiles = copy;
        [self addTransfers: paths];
	}
	return self;
}

- (id) init
{
    if ((self = [super init]))
    {
        self.maxConcurrentOperations = ADBDefaultMaxConcurrentFileTransfers;
    }
    return self;
}

#pragma mark -
#pragma mark Adding transfers


- (void) setCopyFiles: (BOOL)copy
{
    if (copy != self.copyFiles)
    {
        _copyFiles = copy;
        
        for (NSOperation <ADBFileTransfer> *transfer in self.operations)
        {
            [transfer setCopyFiles: copy];
        }
    }
}

- (void) addTransfers: (NSDictionary *)paths
{
    //Build file transfer operations for each pair of paths
	for (NSString *sourcePath in paths.keyEnumerator)
	{
		NSString *destinationPath = [paths objectForKey: sourcePath];
        
        [self addTransferFromPath: sourcePath toPath: destinationPath];
	}
}

- (void) addTransferFromPath: (NSString *)sourcePath
                      toPath: (NSString *)destinationPath
{
    ADBSingleFileTransfer *transfer = [ADBSingleFileTransfer transferFromPath: sourcePath
                                                                       toPath: destinationPath
                                                                    copyFiles: self.copyFiles];
    
    [self.operations addObject: transfer];
}

#pragma mark -
#pragma mark Transfer status

+ (NSSet *)keyPathsForValuesAffectingValueForKey: (NSString *)key
{
	NSSet *baseKeys = [super keyPathsForValuesAffectingValueForKey: key];
	
	NSSet *progressKeys = [NSSet setWithObjects: @"numBytes", @"numFiles", @"bytesTransferred", @"filesTransferred", nil]; 
	
	if ([progressKeys containsObject: key])
        return [baseKeys setByAddingObject: @"currentProgress"];
	else
        return baseKeys;
}
   
- (ADBOperationProgress) currentProgress
{
	unsigned long long totalBytes = self.numBytes;
	if (totalBytes > 0)
	{
		return (ADBOperationProgress)self.bytesTransferred / (ADBOperationProgress)totalBytes;
	}
	else return 0.0f;
}

- (unsigned long long) numBytes
{
	unsigned long long bytes = 0;
	for (ADBOperation <ADBFileTransfer> *operation in self.operations)
	{
		bytes += operation.numBytes;
	}
	return bytes;
}

- (unsigned long long) bytesTransferred
{
	unsigned long long bytes = 0;
	for (ADBOperation <ADBFileTransfer> *operation in self.operations)
	{
		bytes += operation.bytesTransferred;
	}
	return bytes;
}

- (NSUInteger) numFiles
{
	NSUInteger files = 0;
	for (ADBOperation <ADBFileTransfer> *operation in self.operations)
	{
		files += operation.numFiles;
	}
	return files;
}

- (NSUInteger) filesTransferred
{
	NSUInteger files = 0;
	for (ADBOperation <ADBFileTransfer> *operation in self.operations)
	{
		files += operation.filesTransferred;
	}
	return files;
}

- (NSString *) currentPath
{
	for (ADBOperation <ADBFileTransfer> *transfer in self.operations)
	{
		if (transfer.isExecuting)
            return transfer.currentPath;
	}
	return nil;
}

#pragma mark -
#pragma mark Performing the transfer

- (void) _sendInProgressNotificationWithInfo: (NSDictionary *)info
{	
	NSMutableDictionary *extendedInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                   ADBFileTransferFilesTransferredKey: @(self.filesTransferred),
                                                   ADBFileTransferBytesTransferredKey: @(self.bytesTransferred),
                                                         ADBFileTransferFilesTotalKey: @(self.numFiles),
                                                         ADBFileTransferBytesTotalKey: @(self.numBytes),
                                          }];
    if (self.currentPath)
        [extendedInfo setObject: self.currentPath forKey: ADBFileTransferCurrentPathKey];
	
	if (info)
        [extendedInfo addEntriesFromDictionary: info];
	
	[super _sendInProgressNotificationWithInfo: info];
}

- (BOOL) undoTransfer
{
	BOOL undid = NO;
    //Tell each component file transfer to undo whatever it did
    for (ADBOperation <ADBFileTransfer> *transfer in self.operations)
    {
        if ([transfer undoTransfer])
            undid = YES;
    }
	return undid;
}
@end