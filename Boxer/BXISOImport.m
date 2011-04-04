/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXISOImport.h"
#import "BXFileTransfer.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "BXDrive.h"
#import "RegexKitLite.h"


//The default interval in seconds at which to poll the progress of the image operation
//This is set fairly high because hdiutil is a bit of a slouch
#define BXISOImportDefaultPollInterval 5


#pragma mark -
#pragma mark Private method declarations

@interface BXISOImport ()
@property (assign, readwrite) unsigned long long numBytes;
@property (assign, readwrite) unsigned long long bytesTransferred;
@property (assign, readwrite) BXOperationProgress currentProgress;
@property (assign, readwrite, getter=isIndeterminate) BOOL indeterminate;
@property (copy, readwrite) NSString *importedDrivePath;

//Polls a task (stored as the userInfo of the timer) to determine the progress of the task
- (void) _checkImageCreationProgress: (NSTimer *)timer;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXISOImport
@synthesize drive = _drive;
@synthesize destinationFolder	= _destinationFolder;
@synthesize importedDrivePath	= _importedDrivePath;
@synthesize numBytes			= _numBytes;
@synthesize bytesTransferred	= _bytesTransferred;
@synthesize currentProgress		= _currentProgress;
@synthesize indeterminate		= _indeterminate;
@synthesize pollInterval		= _pollInterval;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
	NSString *drivePath = [drive path];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	NSString *volumePath = [workspace volumeForPath: drivePath];
	
	//If the drive is a data CD, then let 'er rip
	if ([volumePath isEqualToString: drivePath] &&
		[[workspace volumeTypeForPath: drivePath] isEqualToString: dataCDVolumeType])
	{
		return YES;
	}
	return NO;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *importedName = nil;
	
	importedName = [[[drive path] lastPathComponent] stringByDeletingPathExtension];
	
	//If the drive has a letter, then prepend it in our standard format
	if ([drive letter]) importedName = [NSString stringWithFormat: @"%@ %@", [drive letter], importedName];
	
	importedName = [importedName stringByAppendingPathExtension: @"iso"];
	
	return importedName;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
					  toDestination: (NSString *)destinationFolder
						  copyFiles: (BOOL)copy;
{
	if ((self = [super init]))
	{
		[self setDrive: drive];
		[self setDestinationFolder: destinationFolder];
		[self setIndeterminate: YES];
		[self setPollInterval: BXISOImportDefaultPollInterval];
	}
	return self;
}

- (void) dealloc
{
	[self setDrive: nil], [_drive release];
	[self setDestinationFolder: nil], [_destinationFolder release];
	[self setImportedDrivePath: nil], [_importedDrivePath release];
	[super dealloc];
}


#pragma mark -
#pragma mark The actual operation

- (BOOL) copyFiles
{
	return YES;
}

- (void) setCopyFiles: (BOOL)flag
{
	//An ISO rip operation is always a copy, so this is a no-op
}

- (void) main
{
	if ([self isCancelled]) return;
	
	NSString *driveName			= [[self class] nameForDrive: [self drive]];
	NSString *sourcePath		= [[self drive] path];
	NSString *destinationPath	= [[self destinationFolder] stringByAppendingPathComponent: driveName];
	
	
	//Determine the /dev/diskx device name of the volume
	NSString *deviceName = [[NSWorkspace sharedWorkspace] BSDNameForVolumePath: sourcePath];
	if (!deviceName)
	{
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: sourcePath forKey: NSFilePathErrorKey];
		NSError *unknownDeviceError = [NSError errorWithDomain: NSCocoaErrorDomain
														  code: NSFileReadUnknownError
													  userInfo: userInfo];
		[self setError: unknownDeviceError];
		return;
	}
	
	//Measure the size of the volume
	NSFileManager *manager = [[NSFileManager alloc] init];
	NSError *volumeSizeError = nil;
	NSDictionary *volumeAttrs = [manager attributesOfFileSystemForPath: sourcePath error: &volumeSizeError];
	if (volumeAttrs)
	{		
		[self setNumBytes: [[volumeAttrs valueForKey: NSFileSystemSize] unsignedLongLongValue]];
	}
	else
	{
		[self setError: volumeSizeError];
		return;
	}
	
	//If the destination filename doesn't end in .cdr, then hdiutil will add it itself:
	//so we'll do so for it, to ensure we know exactly what the destination path will be.
	NSString *tempDestinationPath = destinationPath;
	if (![[[destinationPath pathExtension] lowercaseString] isEqualToString: @"cdr"])
	{
		tempDestinationPath = [destinationPath stringByAppendingPathExtension: @"cdr"];
	}
	
	//Prepare the hdiutil task
	NSTask *hdiutil		= [[NSTask alloc] init];
	NSPipe *outputPipe	= [NSPipe pipe];
	
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"create",
						  @"-srcdevice", deviceName,
						  @"-format", @"UDTO",
						  @"-puppetstrings",
						  @"-plist",
						  tempDestinationPath,
						  nil];
	
	[hdiutil setLaunchPath:		@"/usr/bin/hdiutil"];
	[hdiutil setArguments:		arguments];
	[hdiutil setStandardOutput: outputPipe];
	
	//Last chance to bail out...
	if ([self isCancelled]) return;
	
	//Let's get importing!
	[hdiutil launch];
	
	//Use a timer to poll the task's progress. (This also keeps the runloop below alive.)
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: [self pollInterval]
													  target: self
													selector: @selector(_checkImageCreationProgress:)
													userInfo: hdiutil
													 repeats: YES];
	
	//Run the runloop until the image creation is finished, letting the timer call our polling function.
	//We use a runloop instead of just sleeping, because the runloop lets cancellation messages
	//get dispatched to us correctly.)
	while ([hdiutil isRunning] && [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
														   beforeDate: [NSDate dateWithTimeIntervalSinceNow: [self pollInterval]]])
	{
		//Cancel the image creation if we've been cancelled in the meantime
		//(this will break out of the loop once the task finishes)
		if ([self isCancelled]) [hdiutil terminate];
	}
	[timer invalidate];
	
	[self setSucceeded: [self error] == nil];
	
	//If we succeeded, then rename the new image to its final destination name
	if ([self succeeded])
	{
		if (![destinationPath isEqualToString: tempDestinationPath])
		{
			BOOL moved = [manager moveItemAtPath: tempDestinationPath toPath: destinationPath error: nil];
			//If the move failed then don't worry about it: just use the temporary destination path instead
			if (!moved) destinationPath = tempDestinationPath;
		}
		[self setImportedDrivePath: destinationPath];
	}
}


- (void) _checkImageCreationProgress: (NSTimer *)timer
{
	NSFileHandle *outputHandle = [[[timer userInfo] standardOutput] fileHandleForReading];
	
	NSString *currentOutput = [[NSString alloc] initWithData: [outputHandle availableData] encoding: NSUTF8StringEncoding];
	NSArray *progressValues = [currentOutput componentsMatchedByRegex: @"PERCENT:([\\d.-]+)" capture: 1];
	[currentOutput release];
	
	BXOperationProgress latestProgress = [[progressValues lastObject] floatValue];
	
	if (latestProgress > 0)
	{
		[self setIndeterminate: NO];
		[self setCurrentProgress: latestProgress / 100.0f];
		[self setBytesTransferred: [self numBytes] * [self currentProgress]];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedLongLong:	[self bytesTransferred]],	BXFileTransferBytesTransferredKey,
							  [NSNumber numberWithUnsignedLongLong:	[self numBytes]],			BXFileTransferBytesTotalKey,
							  nil];
		[self _sendInProgressNotificationWithInfo: info];
	}
	else if (latestProgress == -1)
	{
		[self setIndeterminate: YES];
		[self _sendInProgressNotificationWithInfo: nil];
	}
}


- (BOOL) undoTransfer
{
	BOOL undid = NO;
	if ([self importedDrivePath])
	{
		NSFileManager *manager = [[NSFileManager alloc] init];
		undid = [manager removeItemAtPath: [self importedDrivePath] error: nil];
	}
	return undid;
}

@end
