/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
@synthesize numBytes			= _numBytes;
@synthesize bytesTransferred	= _bytesTransferred;
@synthesize currentProgress		= _currentProgress;
@synthesize indeterminate		= _indeterminate;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) driveUnavailableDuringImport
{
    return NO;
}

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	NSString *volumePath = [workspace volumeForPath: drive.path];
	
	//If the drive is a data CD, then let 'er rip
	if ([volumePath isEqualToString: drive.path] &&
		[[workspace volumeTypeForPath: drive.path] isEqualToString: dataCDVolumeType])
	{
		return YES;
	}
	return NO;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *importedName = nil;
	
	importedName = drive.path.lastPathComponent.stringByDeletingPathExtension;
	
	//If the drive has a letter, then prepend it in our standard format
	if (drive.letter) importedName = [NSString stringWithFormat: @"%@ %@", drive.letter, importedName];
	
	importedName = [importedName stringByAppendingPathExtension: @"iso"];
	
	return importedName;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXDriveImport>) init
{
	if ((self = [super init]))
	{
		self.indeterminate = YES;
	}
	return self;
}

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
					  toDestination: (NSString *)destinationFolder
						  copyFiles: (BOOL)copy;
{
	if ((self = [self init]))
	{
        self.drive = drive;
        self.destinationFolder = destinationFolder;
	}
	return self;
}

- (void) dealloc
{
    self.drive = nil;
    self.destinationFolder = nil;
    
	[super dealloc];
}


#pragma mark -
#pragma mark The actual operation

- (NSUInteger) numFiles
{
	//An ISO rip operation always results in a single ISO file being generated.
    return 1;
}
- (NSUInteger) filesTransferred
{
    return self.succeeded ? 1 : 0;
}

- (NSString *) currentPath
{
    return self.isFinished ? nil : self.drive.path;
}

- (BOOL) copyFiles
{
	return YES;
}

- (void) setCopyFiles: (BOOL)flag
{
	//An ISO rip operation is always a copy, so this is a no-op
}

- (NSString *) importedDrivePath
{
    if (!self.drive || !self.destinationFolder) return nil;
    
	NSString *driveName			= [self.class nameForDrive: self.drive];
	NSString *destinationPath	= [self.destinationFolder stringByAppendingPathComponent: driveName];
    
    return destinationPath;
}

- (BOOL) shouldPerformOperation
{
    return [super shouldPerformOperation] && self.drive && self.destinationFolder;
}

- (void) performOperation
{
	NSString *sourcePath		= self.drive.path;
	NSString *destinationPath	= self.importedDrivePath;
	
	//Measure the size of the volume to determine how much data we'll be importing
	NSFileManager *manager = [[NSFileManager alloc] init];
	NSError *volumeSizeError = nil;
	NSDictionary *volumeAttrs = [manager attributesOfFileSystemForPath: sourcePath error: &volumeSizeError];
	if (volumeAttrs)
	{		
		self.numBytes = [[volumeAttrs objectForKey: NSFileSystemSize] unsignedLongLongValue];
	}
	else
	{
		self.error = volumeSizeError;
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
		self.error = unknownDeviceError;
		[manager release];
		return;
	}
	
	//If the destination filename doesn't end in .cdr, then hdiutil will add it itself:
	//so we'll do so for it, to ensure we know exactly what the destination path will be.
	NSString *tempDestinationPath = destinationPath;
	if (![destinationPath.pathExtension.lowercaseString isEqualToString: @"cdr"])
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
	
	hdiutil.launchPath = @"/usr/bin/hdiutil";
	hdiutil.arguments = arguments;
	hdiutil.standardOutput = [NSPipe pipe];
	hdiutil.standardError = [NSPipe pipe];
	
	self.task = hdiutil;
	[hdiutil release];
	
	//Run the task to completion and monitor its progress
    _hasWrittenFiles = NO;
	[self runTask];
    _hasWrittenFiles = YES;
	
	if (!self.error)
	{
		//If image creation succeeded, then rename the new image to its final destination name
		if ([manager fileExistsAtPath: tempDestinationPath])
		{
			if (![destinationPath isEqualToString: tempDestinationPath])
			{
                NSError *renameError = nil;
				BOOL moved = [manager moveItemAtPath: tempDestinationPath
                                              toPath: destinationPath
                                               error: &renameError];
                
                if (!moved)
                {
                    self.error = renameError;
                }
			}
		}
		else
		{
			self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		}
	}
	
	[manager release];
    
    
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error) [self undoTransfer];
}

- (void) checkTaskProgress: (NSTimer *)timer
{
    NSTask *task = timer.userInfo;
	NSFileHandle *outputHandle = [task.standardOutput fileHandleForReading];
	
	NSString *currentOutput = [[NSString alloc] initWithData: outputHandle.availableData
                                                    encoding: NSUTF8StringEncoding];
	NSArray *progressValues = [currentOutput componentsMatchedByRegex: @"PERCENT:(-?[0-9\\.]+)" capture: 1];
	[currentOutput release];
	
	BXOperationProgress latestProgress = [progressValues.lastObject floatValue];
	
	if (latestProgress > 0)
	{
		self.indeterminate = NO;
		//hdiutil expresses progress as a float percentage from 0 to 100
		self.currentProgress = latestProgress / 100.0f;
		self.bytesTransferred = (self.numBytes * (double)self.currentProgress);
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedLongLong:	self.bytesTransferred],	BXFileTransferBytesTransferredKey,
							  [NSNumber numberWithUnsignedLongLong:	self.numBytes],			BXFileTransferBytesTotalKey,
							  nil];
		[self _sendInProgressNotificationWithInfo: info];
	}
	//hdiutil will print "-1" when its own progress is indeterminate
	//q.v. man hdiutil and search for -puppetstrings
	else if (latestProgress == -1)
	{
		self.indeterminate = YES;
		[self _sendInProgressNotificationWithInfo: nil];
	}
}


- (BOOL) undoTransfer
{
	BOOL undid = NO;
    NSString *destinationPath = self.importedDrivePath;
	if (destinationPath && _hasWrittenFiles)
	{
		NSFileManager *manager = [[NSFileManager alloc] init];
		undid = [manager removeItemAtPath: destinationPath error: nil];
        [manager release];
	}
	return undid;
}

@end


@implementation BXCDImageImportRipFailedError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = drive.title;
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted into a disc image.",
													@"Error shown when CD-image ripping fails for an unknown reason. %1$@ is the display title of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName, nil];
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   description, NSLocalizedDescriptionKey,
							   [drive path], NSFilePathErrorKey,
							   nil];
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain
                               code: BXCDImageImportErrorRipFailed
                           userInfo: userInfo];
}
@end


@implementation BXCDImageImportDiscInUseError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = drive.title;
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted to a disc image because it is in use by another application.",
													@"Error shown when CD-image ripping fails because the disc is in use. %1$@ is the display title of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName, nil];
	NSString *suggestion	= NSLocalizedString(@"Close Finder windows or other applications that are using the disc, then try importing again.", @"Explanatory message shown when CD-image ripping fails because the disc is in use.");
	
	NSDictionary *userInfo	= [NSDictionary dictionaryWithObjectsAndKeys:
							   description,		NSLocalizedDescriptionKey,
							   suggestion,		NSLocalizedRecoverySuggestionErrorKey,
							   [drive path],	NSFilePathErrorKey,
							   nil];
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain
                               code: BXCDImageImportErrorDiscInUse
                           userInfo: userInfo];
}
@end