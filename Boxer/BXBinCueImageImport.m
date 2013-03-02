/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBinCueImageImport.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "BXDrive.h"
#import <DiskArbitration/DiskArbitration.h>
#import "RegexKitLite.h"
#import "ADBFileTransfer.h"


#pragma mark -
#pragma mark Private function declarations

enum
{
	BXDADiskOperationInProgress = -1,
	BXDADiskOperationFailed = 0,
	BXDADiskOperationSucceeded = 1
};
typedef NSInteger BXDADiskOperationStatus;

BOOL _mountSynchronously(DASessionRef, DADiskRef disk, CFURLRef path, DADiskUnmountOptions options);
BOOL _unmountSynchronously(DASessionRef session, DADiskRef disk, DADiskMountOptions options);
void _mountCallback(DADiskRef disk, DADissenterRef dissenter, void *status);

#pragma mark -
#pragma mark Implementation

void _mountCallback(DADiskRef disk, DADissenterRef dissenter, void *status)
{
	*(BXDADiskOperationStatus *)status = (dissenter != NULL) ? BXDADiskOperationFailed : BXDADiskOperationSucceeded;
}

//DADiskUnmount is asynchronous, so this function calls it and blocks while it waits
//for the callback to answer whether the disk unmounted successfully or not.
BOOL _unmountSynchronously(DASessionRef session, DADiskRef disk, DADiskUnmountOptions options)
{
	BXDADiskOperationStatus status = BXDADiskOperationInProgress;
	NSRunLoop *loop = [NSRunLoop currentRunLoop];
	CFRunLoopRef cfLoop = [loop getCFRunLoop];
	
	DASessionScheduleWithRunLoop(session, cfLoop, kCFRunLoopDefaultMode);
	DADiskUnmount(disk, options, _mountCallback, &status);
	
	while (status == BXDADiskOperationInProgress)
	{
		[loop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	}
	
	DASessionUnscheduleFromRunLoop(session, cfLoop, kCFRunLoopDefaultMode);
	
	return status == BXDADiskOperationSucceeded;
}

BOOL _mountSynchronously(DASessionRef session, DADiskRef disk, CFURLRef path, DADiskMountOptions options)
{
	BXDADiskOperationStatus status = BXDADiskOperationInProgress;
	NSRunLoop *loop = [NSRunLoop currentRunLoop];
	CFRunLoopRef cfLoop = [loop getCFRunLoop];
	
	DASessionScheduleWithRunLoop(session, cfLoop, kCFRunLoopDefaultMode);
	DADiskMount(disk, path, options, _mountCallback, &status);
	
	while (status == BXDADiskOperationInProgress)
	{
		[loop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	}
	DASessionUnscheduleFromRunLoop(session, cfLoop, kCFRunLoopDefaultMode);
	
	return status == BXDADiskOperationSucceeded;
}


@implementation BXBinCueImageImport
@synthesize usesErrorCorrection = _usesErrorCorrection;

+ (BOOL) driveUnavailableDuringImport
{
    //cdrdao requires the source volume to be unmounted before it can rip it.
    return YES;
}

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
	NSString *drivePath = drive.path;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	
	NSString *volumePath = [workspace volumeForPath: drivePath];
	
	if ([volumePath isEqualToString: drivePath])
	{
		NSString *volumeType = [workspace volumeTypeForPath: drivePath];
		
		//If it's an audio CD, we can import it just fine.
		if ([volumeType isEqualToString: ADBAudioCDVolumeType]) return YES;
		
		//If it's a data CD, check if it has a matching audio volume: if so, then a BIN/CUE image is needed.
		//(Otherwise, we'll let BXCDImageImport handle it.)
		else if ([volumeType isEqualToString: ADBDataCDVolumeType] &&
				 [workspace audioVolumeOfDataCD: volumePath] != nil) return YES;
		
		//Pass on all other volume types.
		return NO;
	}
	return NO;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *baseName = [BXDriveImport baseNameForDrive: drive];
	NSString *importedName = [baseName stringByAppendingPathExtension: @"cdmedia"];
	
	return importedName;
}

- (id <BXDriveImport>) init
{
	if ((self = [super init]))
	{
		_manager = [[NSFileManager alloc] init];
        self.usesErrorCorrection = [[NSUserDefaults standardUserDefaults] boolForKey: @"useBinCueErrorCorrection"];
 	}
	return self;
}

- (void) dealloc
{
	[_manager release], _manager = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Task execution

- (void) main
{
    NSAssert(self.drive != nil, @"No drive provided for drive import operation.");
    NSAssert(self.destinationURL != nil || self.destinationFolderURL != nil, @"No destination folder provided for drive import operation.");
    
    if (!self.destinationURL)
        self.destinationURL = self.preferredDestinationURL;
    
    _hasWrittenFiles = NO;
    
	NSString *sourcePath		= self.drive.path;
	NSString *destinationPath	= self.destinationURL.path;
	
	NSString *tocName	= @"tracks.toc";
	NSString *cueName	= @"tracks.cue";
	NSString *binName	= @"data.bin";
	
	
	//Determine the /dev/diskx device name for the imported volume
	NSString *volumeDeviceName = [[NSWorkspace sharedWorkspace] BSDDeviceNameForVolumeAtURL: [NSURL fileURLWithPath: sourcePath]];
	if (!volumeDeviceName)
	{
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: sourcePath forKey: NSFilePathErrorKey];
		NSError *unknownDeviceError = [NSError errorWithDomain: NSCocoaErrorDomain
														  code: NSFileReadUnknownError
													  userInfo: userInfo];
		self.error = unknownDeviceError;
		return;
	}
	
	//Find the BSD name of the entire disk, so that we can import all its tracks
	NSString *baseDeviceName = [volumeDeviceName stringByMatching: @"(/dev/disk\\d+)(s\\d+)?" capture: 1];
	
	//Use the BSD name to acquire a Disk Arbitration object for the disc
	DASessionRef session = DASessionCreate(kCFAllocatorDefault);
	if (!session)
	{
		self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		return;
	}
	
	DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, baseDeviceName.fileSystemRepresentation);
	if (!disk)
	{
		self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		CFRelease(session);
		return;
	}
	
	NSString *devicePath = nil;
	unsigned long long diskSize = 0;
	
	//Get the I/O Registry device path to feed to cdrdao, along with the total size of the volume
	//so that we know how much we'll be importing today
	CFDictionaryRef description = DADiskCopyDescription(disk);
	if (description)
	{
		CFStringRef pathRef = CFDictionaryGetValue(description, kDADiskDescriptionDevicePathKey);
		CFNumberRef sizeRef = CFDictionaryGetValue(description, kDADiskDescriptionMediaSizeKey);
		
		devicePath	= [[(__bridge NSString *)pathRef copy] autorelease];
		diskSize	= [(__bridge NSNumber *)sizeRef unsignedLongLongValue];
		
		CFRelease(description);
	}
	//If we couldn't determine those for whatever reason then fail early now
	else
	{
		self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		CFRelease(disk);
		CFRelease(session);
		return;
	}
	
	self.numBytes = diskSize;
    
	//Create the .cdimage wrapper for the imported image, since it shouldn't exist yet.
	NSError *destinationCreationError = nil;
	BOOL createdDestination = [_manager createDirectoryAtPath: destinationPath
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: &destinationCreationError];
	//If it does exist, or we can't create it for some reason, then stop importing and fail with an error.
	if (!createdDestination)
	{
		self.error = destinationCreationError;
		CFRelease(disk);
		CFRelease(session);
		return;
	}
	
	//At this point we have started creating data; record this fact so that we will
	//clean up our partial files in BXCDImageImport -undoTransfer if the import is aborted.
	_hasWrittenFiles = YES;

	
	//Unmount the disc's volume without ejecting it, so that cdrdao can access the device exclusively.
	BOOL unmounted = _unmountSynchronously(session, disk, kDADiskUnmountOptionWhole);
	
	//If we couldn't unmount the disc then assume it's still in use and fail.
	if (!unmounted)
	{
		self.error = [BXCDImageImportDiscInUseError errorWithDrive: self.drive];
		
		CFRelease(disk);
		CFRelease(session);
		return;
	}
	
	//Once we get this far, we're ready to actually start the image-ripping task.
	//(From this point on, if we fail, we have to remount the disk.)

	NSTask *cdrdao = [[NSTask alloc] init];
	NSString *cdrdaoPath = [[NSBundle mainBundle] pathForResource: @"cdrdao" ofType: nil];
	
	//3 is the maximum error correction level, 0 disables error correction altogether.
	//The three different types of error correct make negligible difference to the overall speed:
	//they all take about twice as long compared to no error-detection.
	NSString *errorCorrectionLevel = (self.usesErrorCorrection) ? @"3" : @"0";
	
	//cdrdao uses relative paths in cuesheets as long as we use relative paths, which simplifies our job,
	//so we provide just the file names as arguments and change the task's working directory to where
	//we want them put.
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"read-cd",
						  @"--read-raw",
						  @"--paranoia-mode", errorCorrectionLevel,
						  @"--device", devicePath,
						  @"--driver", @"generic-mmc:0x20000",
						  @"--datafile", binName,
						  tocName,
						  nil];
	
	cdrdao.currentDirectoryPath = destinationPath;
	cdrdao.launchPath = cdrdaoPath;
	cdrdao.arguments = arguments;
	
	self.task = cdrdao;
	[cdrdao release];
	
	//Run the task to completion and monitor its progress
	[super main];
	
	//If the image creation went smoothly, do final cleanup
	if (!self.error)
	{
		NSString *tocPath = [destinationPath stringByAppendingPathComponent: tocName];
		NSString *cuePath = [destinationPath stringByAppendingPathComponent: cueName];
		if ([_manager fileExistsAtPath: tocPath])
		{
			//Now, convert the TOC file to a CUE
			NSTask *toc2cue = [[NSTask alloc] init];
			
			toc2cue.launchPath = [[NSBundle mainBundle] pathForResource: @"toc2cue" ofType: nil];
			toc2cue.arguments = [NSArray arrayWithObjects: tocPath, cuePath, nil];
			toc2cue.standardOutput = [NSFileHandle fileHandleWithNullDevice];
			
			//toc2cue takes hardly any time to run, so just block until it finishes.
			[toc2cue launch];
			[toc2cue waitUntilExit];
			[toc2cue release];
			
			//Once the CUE file is ready, delete the original TOC.
			if ([_manager fileExistsAtPath: cuePath])
			{
				[_manager removeItemAtPath: tocPath error: nil];
			}
			//Treat it as a fatal error if the CUE file was not generated successfully.
			else
			{
				self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
			}
		}
		//If the TOC file wasn't created, something went wrong in the ripping process.
		else
		{
			self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		}
	}
    
	//Ensure the disk is remounted after we're done with everything, whether we succeeded or failed
	_mountSynchronously(session, disk, NULL, kDADiskMountOptionWhole); 
	
	//Release Disk Arbitration resources
	CFRelease(disk);
	CFRelease(session);
    
    
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error)
        [self undoTransfer];
}

- (void) checkTaskProgress: (NSTimer *)timer
{
	if (self.numBytes > 0)
	{
		//Rather than bothering to parse the output of cdrdao, we just compare how large
		//the image is so far to the total size of the original disk.
		
		NSString *imagePath = [self.destinationURL URLByAppendingPathComponent: @"data.bin"].path;
		unsigned long long imageSize = [_manager attributesOfItemAtPath: imagePath error: nil].fileSize;
		
		if (imageSize > 0)
		{
			//The image may end up being larger than the original volume, so cap the reported size.
			imageSize = MIN(imageSize, self.numBytes);
			
			self.indeterminate = NO;
			self.bytesTransferred = imageSize;
			
			ADBOperationProgress progress = (float)self.bytesTransferred / (float)self.numBytes;
			//Add a margin at either side of the progress to account for lead-in, cleanup and TOC conversion
			//TODO: move this upstream into setCurrentProgress or somewhere
			progress = 0.03f + (progress * 0.97f);
			self.currentProgress = progress;
			
			NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithUnsignedLongLong: self.bytesTransferred],	ADBFileTransferBytesTransferredKey,
				[NSNumber numberWithUnsignedLongLong: self.numBytes],			ADBFileTransferBytesTotalKey,
			nil];
			
			[self _sendInProgressNotificationWithInfo: info];
		}
		else
		{
			self.indeterminate = YES;
			[self _sendInProgressNotificationWithInfo: nil];
		}
	}
	else
	{
		self.indeterminate = YES;
		[self _sendInProgressNotificationWithInfo: nil];
	}
}
@end
