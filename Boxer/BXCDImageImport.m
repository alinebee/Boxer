/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCDImageImport.h"
#import "BXFileTransfer.h"
#import "NSWorkspace+BXMountedVolumes.h"
#import "BXDrive.h"
#import "RegexKitLite.h"


NSString * const BXCDImageImportErrorDomain = @"BXCDImageImportErrorDomain";


#pragma mark -
#pragma mark Implementations

@implementation BXCDImageImport
@synthesize drive = _drive;
@synthesize destinationFolder	= _destinationFolder;
@synthesize importedDrivePath	= _importedDrivePath;
@synthesize numBytes			= _numBytes;
@synthesize bytesTransferred	= _bytesTransferred;
@synthesize currentProgress		= _currentProgress;
@synthesize indeterminate		= _indeterminate;


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

- (id <BXDriveImport>) init
{
	if ((self = [super init]))
	{
		[self setIndeterminate: YES];
	}
	return self;
}

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
					  toDestination: (NSString *)destinationFolder
						  copyFiles: (BOOL)copy;
{
	if ((self = [self init]))
	{
		[self setDrive: drive];
		[self setDestinationFolder: destinationFolder];
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
	if ([self isCancelled] || ![self drive] || ![self destinationFolder]) return;
	
	NSString *driveName			= [[self class] nameForDrive: [self drive]];
	NSString *sourcePath		= [[self drive] path];
	NSString *destinationPath	= [[self destinationFolder] stringByAppendingPathComponent: driveName];
	
	//Measure the size of the volume to determine how much data we'll be importing
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
		[manager release];
		return;
	}
	
	//Determine the /dev/diskx device name of the volume
	NSString *deviceName = [[NSWorkspace sharedWorkspace] BSDNameForVolumePath: sourcePath];
	if (!deviceName)
	{
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: sourcePath forKey: NSFilePathErrorKey];
		NSError *unknownDeviceError = [NSError errorWithDomain: NSCocoaErrorDomain
														  code: NSFileReadUnknownError
													  userInfo: userInfo];
		[self setError: unknownDeviceError];
		[manager release];
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
	NSTask *hdiutil = [[NSTask alloc] init];
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"create",
						  @"-srcdevice", deviceName,
						  @"-format", @"UDTO",
						  @"-puppetstrings",
						  tempDestinationPath,
						  nil];
	
	[hdiutil setLaunchPath:		@"/usr/bin/hdiutil"];
	[hdiutil setArguments:		arguments];
	[hdiutil setStandardOutput: [NSPipe pipe]];
	[hdiutil setStandardError:	[NSPipe pipe]];
	
	[self setTask: hdiutil];
	[hdiutil release];
	
	//Run the task to completion and monitor its progress
	[self runTask];
	
	if (![self error])
	{
		//If image creation succeeded, then rename the new image to its final destination name
		if ([manager fileExistsAtPath: tempDestinationPath])
		{
			if (![destinationPath isEqualToString: tempDestinationPath])
			{
				BOOL moved = [manager moveItemAtPath: tempDestinationPath toPath: destinationPath error: nil];
				//If the move failed then don't worry about it: just use the temporary destination path instead
				if (!moved) destinationPath = tempDestinationPath;
				
			}
			[self setImportedDrivePath: destinationPath];
		}
		else
		{
			[self setError: [BXCDImageImportRipFailedError errorWithDrive: [self drive]]];
		}
	}
	
	[self setSucceeded: [self error] == nil];
	
	[manager release];
}

- (void) checkTaskProgress: (NSTimer *)timer
{
	NSFileHandle *outputHandle = [[[timer userInfo] standardOutput] fileHandleForReading];
	
	NSString *currentOutput = [[NSString alloc] initWithData: [outputHandle availableData] encoding: NSUTF8StringEncoding];
	NSArray *progressValues = [currentOutput componentsMatchedByRegex: @"PERCENT:(-?[0-9\\.]+)" capture: 1];
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


@implementation BXCDImageImportRipFailedError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = [drive label];
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted into a disc image.",
													@"Error shown when CD-image ripping fails for an unknown reason. %1$@ is the volume label of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName, nil];
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   description, NSLocalizedDescriptionKey,
							   [drive path], NSFilePathErrorKey,
							   nil];
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain code: BXCDImageImportErrorRipFailed userInfo: userInfo];
}
@end


@implementation BXCDImageImportDiscInUseError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = [drive label];
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted to a disc image because it is in use by another application.",
													@"Error shown when CD-image ripping fails because the disc is in use. %1$@ is the volume label of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName, nil];
	NSString *suggestion	= NSLocalizedString(@"Close Finder windows or other applications that are using the disc, then try importing again.", @"Explanatory message shown when CD-image ripping fails because the disc is in use.");
	
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   description,		NSLocalizedDescriptionKey,
							   suggestion,		NSLocalizedRecoverySuggestionErrorKey,
							   [drive path],	NSFilePathErrorKey,
							   nil];
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain code: BXCDImageImportErrorDiscInUse userInfo: userInfo];
}
@end