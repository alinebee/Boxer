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

NSString * const BXFileTransferDidFinish	= @"BXFileTransferDidFinish";
NSString * const BXFileTransferInProgress	= @"BXFileTransferInProgress";

NSString * const BXFileTransferSuccessKey	= @"BXFileTransferSuccessKey";
NSString * const BXFileTransferErrorKey		= @"BXFileTransferErrorKey";
NSString * const BXFileTransferProgressKey	= @"BXFileTransferProgressKey";
NSString * const BXFileTransferCurrentPathKey	= @"BXFileTransferCurrentPathKey";



#pragma mark -
#pragma mark Private method declarations

@interface BXFileTransfer ()

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
@synthesize delegate;
@synthesize copyFiles, sourcePath, destinationPath;
@synthesize numFiles, numFilesTransferred, currentPath;
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
	//Sanity check: if we have no source or destination path, bail out now
	if (![self sourcePath] || ![self destinationPath]) return;
	
	NSUInteger fileCount = 0;
	BOOL transferSucceeded = NO;
	NSError *transferError = nil;
	
	//Calculate how many files are involved in our copy operation
	for (NSString *path in [manager enumeratorAtPath: [self sourcePath]]) fileCount++;
	
	[self setNumFiles: fileCount];
	[self setNumFilesTransferred: 0];
	
	//TODO: check if we need to enumerate the directory in order to get "should I copy this file" checks
	if (copyFiles)
	{
		transferSucceeded = [manager copyItemAtPath: [self sourcePath] toPath: [self destinationPath] error: &transferError];
	}
	else
	{
		transferSucceeded = [manager moveItemAtPath: [self sourcePath] toPath: [self destinationPath] error: &transferError];
	}
	[self setSucceeded: transferSucceeded];
	[self setError: transferError];
	
	//If a copy operation was cancelled or ended in an error, then delete the destination path to clean up
	//TODO: for move operations, we should move the files back.
	//TODO: check that NSFileManager doesn't do all this for us!
	if (copyFiles && (!transferSucceeded || [self isCancelled]))
	{
		[manager removeItemAtPath: [self destinationPath] error: nil];
	}
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithBool: [self succeeded]], BXFileTransferSuccessKey,
							  [self error], BXFileTransferErrorKey,
							  nil];
	
	[self _postNotificationName: BXFileTransferDidFinish
			   delegateSelector: @selector(fileTransferDidFinish:)
					   userInfo: userInfo];
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
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSNotification *notification = [NSNotification notificationWithName: name
																 object: self
															   userInfo: userInfo];
	
	if ([[self delegate] respondsToSelector: selector])
		[[self delegate] performSelectorOnMainThread: selector withObject: notification waitUntilDone: NO];
	
	[center performSelectorOnMainThread: @selector(postNotification:) withObject: notification waitUntilDone: NO];
}
@end