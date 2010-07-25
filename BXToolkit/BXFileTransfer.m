/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFileTransfer.h"
#import "BXFileTransferDelegate.h"

#pragma mark -
#pragma mark Notification constants and keys

NSString * const BXFileTransferWillStart		= @"BXFileTransferWillStart";
NSString * const BXFileTransferDidStart			= @"BXFileTransferDidStart";
NSString * const BXFileTransferDidFinish		= @"BXFileTransferDidFinish";
NSString * const BXFileTransferInProgress		= @"BXFileTransferInProgress";
NSString * const BXFileTransferWasCancelled		= @"BXFileTransferWasCancelled";

NSString * const BXFileTransferContextInfoKey	= @"BXFileTransferContextInfoKey";
NSString * const BXFileTransferSuccessKey		= @"BXFileTransferSuccessKey";
NSString * const BXFileTransferErrorKey			= @"BXFileTransferErrorKey";
NSString * const BXFileTransferFileCountKey		= @"BXFileTransferFileCountKey";
NSString * const BXFileTransferTotalSizeKey		= @"BXFileTransferTotalSizeKey";
NSString * const BXFileTransferProgressKey		= @"BXFileTransferProgressKey";
NSString * const BXFileTransferCurrentPathKey	= @"BXFileTransferCurrentPathKey";



#pragma mark -
#pragma mark Private method declarations

@interface BXFileTransfer ()

@property (readwrite) unsigned long long transferSize;
@property (readwrite) NSUInteger numFiles;
@property (readwrite) NSUInteger numFilesTransferred;
@property (readwrite, copy) NSString *currentPath;
@property (readwrite) BOOL succeeded;
@property (readwrite, retain) NSError *error;

//General-purpose responder to the more specific NSFileManager delegate methods.
//Returns NO if the operation is cancelled.
- (BOOL) _shouldTransferItemAtPath: (NSString *)srcPath toPath:(NSString *)dstPath;

//Shortcut method for sending a notification both to the default notification center
//and to a selector on our delegate. The object of the notification will be self.
- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo;
@end

#pragma mark -
#pragma mark Implementation

@implementation BXFileTransfer
@synthesize delegate, contextInfo;
@synthesize copyFiles, sourcePath, destinationPath;
@synthesize numFiles, numFilesTransferred, transferSize, currentPath;
@synthesize succeeded, error;

#pragma mark -
#pragma mark Initialization and deallocation

- (id)initFromPath: (NSString *)source toPath: (NSString *)destination copyFiles: (BOOL)copy
{
	if ((self = [super init]))
	{
		[self setSourcePath: source];
		[self setDestinationPath: destination];
		[self setCopyFiles: copy];
		
		//Create our own personal file manager instance and set ourselves as the delegate
		manager = [[NSFileManager alloc] init];
		[manager setDelegate: self];
	}
	return self;
}

+ (id) transferFromPath: (NSString *)source toPath: (NSString *)destination copyFiles: (BOOL)copy
{
	return [[[self alloc] initFromPath: source toPath: destination copyFiles: copy] autorelease];
}

- (void) dealloc
{
	[manager setDelegate: nil];
	[manager release], manager = nil;
	
	[self setContextInfo: nil],		[contextInfo release];
	[self setError: nil],			[error release];
	[self setCurrentPath: nil],		[currentPath release];
	[self setSourcePath: nil],		[sourcePath release];
	[self setDestinationPath: nil],	[destinationPath release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Inspecting the transfer

+ (NSSet *) keyPathsForValuesAffectingCurrentProgress
{
	return [NSSet setWithObjects: @"numFilesTransferred", @"numFiles", nil];
}

- (BXFileTransferProgress) currentProgress
{
	return (BXFileTransferProgress)numFilesTransferred / (BXFileTransferProgress)numFiles;
}


#pragma mark -
#pragma mark Performing the transfer

- (void) main
{
	//Sanity checks: if we have no source or destination path or we're already cancelled, bail out now
	if ([self isCancelled] || ![self sourcePath] || ![self destinationPath]) return;
	
	BOOL sourceIsDir, sourceExists = [manager fileExistsAtPath: [self sourcePath] isDirectory: &sourceIsDir];
	BOOL destinationExists = [manager fileExistsAtPath: [self destinationPath]];
	
	//Bail out if the source path does not exist or if the destination path does exist
	//TODO: populate the error also.
	if (!sourceExists || destinationExists) return;
	
	BOOL transferSucceeded = NO;
	NSError *transferError = nil;
	
	//Once we get to this point we know we'll continue, so send a willStart notification
	[self _postNotificationName: BXFileTransferWillStart
			   delegateSelector: @selector(fileTransferWillStart:)
					   userInfo: nil];
	
	
	//There will always be at least one file to be transferred: the source path (be it a file or folder)
	NSUInteger fileCount = 1;
	unsigned long long totalFileSize = [[[manager attributesOfItemAtPath: [self sourcePath] error: NULL] objectForKey: NSFileSize] unsignedLongLongValue];
	
	//When source is a directory, calculate how many additional files will be transferred from within it
	if (sourceIsDir)
	{
		NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath: [self sourcePath]];
		for (NSString *path in enumerator)
		{
			fileCount++;
			NSDictionary *attrs = [enumerator fileAttributes];
			totalFileSize += [[attrs objectForKey: NSFileSize] unsignedLongLongValue];
		}
	}

	[self setNumFiles: fileCount];
	[self setNumFilesTransferred: 0];
	[self setTransferSize: totalFileSize];

	//Now that we know how big the operation will be, send a didStart notification
	NSDictionary *startInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithUnsignedInteger: [self numFiles]], BXFileTransferFileCountKey,
							   [NSNumber numberWithUnsignedLongLong: [self transferSize]], BXFileTransferTotalSizeKey,
							   nil];
	
	[self _postNotificationName: BXFileTransferDidStart
			   delegateSelector: @selector(fileTransferDidStart:)
					   userInfo: startInfo];
	
	if (copyFiles)
	{
		transferSucceeded = [manager copyItemAtPath: [self sourcePath] toPath: [self destinationPath] error: &transferError];
	}
	else
	{
		transferSucceeded = [manager moveItemAtPath: [self sourcePath] toPath: [self destinationPath] error: &transferError];
	}
	
	if (transferSucceeded && [self isCancelled])
	{
		transferSucceeded = NO;
		transferError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSUserCancelledError userInfo: nil];
	}
	
	[self setSucceeded: transferSucceeded];
	[self setError: transferError];
	
	if (transferSucceeded)
	{
		//If the source path was a volume, the creation and modification dates of the transferred path will be empty.
		//In this case, fill them with today's date.
		NSDictionary *destinationAttrs = [manager attributesOfItemAtPath: [self destinationPath] error: NULL];
		NSDate *modDate			= [destinationAttrs fileModificationDate];
		NSDate *creationDate	= [destinationAttrs fileCreationDate];
		
		NSMutableDictionary *newDateAttrs = [NSMutableDictionary dictionaryWithCapacity: 2];
		if (!modDate || [modDate timeIntervalSince1970] <= 0)
			[newDateAttrs setObject: [NSDate date] forKey: NSFileModificationDate];
		if (!creationDate || [creationDate timeIntervalSince1970] <= 0)
			[newDateAttrs setObject: [NSDate date] forKey: NSFileCreationDate]; 
		
		[manager setAttributes: newDateAttrs ofItemAtPath: [self destinationPath] error: NULL];
	}
	
	//If a copy operation was cancelled or ended in an error, then delete the destination path to clean up
	//TODO: for move operations, we should move the files back.
	if (copyFiles && !transferSucceeded)
	{
		[manager removeItemAtPath: [self destinationPath] error: nil];
	}
	
	NSDictionary *finishInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithBool: [self succeeded]], BXFileTransferSuccessKey,
								[self error], BXFileTransferErrorKey,
								nil];
	
	[self _postNotificationName: BXFileTransferDidFinish
			   delegateSelector: @selector(fileTransferDidFinish:)
					   userInfo: finishInfo];
}

- (void) cancel
{	
	//Only send a notification the first time we're cancelled,
	//and only if we're in progress when we get cancelled
	if (![self isCancelled] && [self isExecuting])
	{
		[super cancel];
		[self _postNotificationName: BXFileTransferWasCancelled
				   delegateSelector: @selector(fileTransferWasCancelled:)
						   userInfo: nil];		
	}
	else [super cancel];
}

- (BOOL) fileManager: (NSFileManager *)fileManager shouldCopyItemAtPath: (NSString *)srcPath toPath: (NSString *)dstPath
{
	return [self _shouldTransferItemAtPath: srcPath toPath: dstPath];
}

- (BOOL) fileManager: (NSFileManager *)fileManager shouldMoveItemAtPath: (NSString *)srcPath toPath: (NSString *)dstPath
{
	return [self _shouldTransferItemAtPath: srcPath toPath: dstPath];
}

- (BOOL) _shouldTransferItemAtPath: (NSString *)srcPath toPath: (NSString *)dstPath
{
	if ([self isCancelled]) return NO;
	
	[self setCurrentPath: srcPath];
	[self setNumFilesTransferred: [self numFilesTransferred] + 1];
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithFloat: [self currentProgress]], BXFileTransferProgressKey,
							  [self currentPath], BXFileTransferCurrentPathKey,
							  nil];
	
	[self _postNotificationName: BXFileTransferInProgress
			   delegateSelector: @selector(fileTransferInProgress:)
					   userInfo: userInfo];
	return YES;
}

- (void) _postNotificationName: (NSString *)name
			  delegateSelector: (SEL)selector
					  userInfo: (NSDictionary *)userInfo
{
	//Extend the notification dictionary with context info, if context was provided
	if ([self contextInfo])
	{
		NSMutableDictionary *extendedInfo = [NSMutableDictionary dictionaryWithObject: [self contextInfo] forKey: BXFileTransferContextInfoKey];
		if (userInfo) [extendedInfo addEntriesFromDictionary: userInfo];
		userInfo = extendedInfo;
	}
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	if ([[self delegate] respondsToSelector: selector])
		[(id)[self delegate] performSelectorOnMainThread: selector withObject: notification waitUntilDone: NO];
	
	[center performSelectorOnMainThread: @selector(postNotification:) withObject: notification waitUntilDone: NO];
}
@end