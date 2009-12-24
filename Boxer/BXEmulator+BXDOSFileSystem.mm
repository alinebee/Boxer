/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "BXDrive.h"

#import "dos_inc.h"
#import "dos_system.h"
#import "drives.h"
#import "cdrom.h"

//Defined in dos_files.cpp
extern DOS_Drive * Drives[DOS_DRIVES];

//Defined in dos_mscdex.cpp
void MSCDEX_SetCDInterface(int intNr, int forceCD);


//Drive geometry constants passed to _DOSBoxDriveFromPath:freeSpace:geometry:mediaID
BXDriveGeometry BXHardDiskGeometry		= {512, 127, 16383, 4031};	//~1GB, ~250MB free space
BXDriveGeometry BXFloppyDiskGeometry	= {512, 1, 2880, 2880};		//1.44MB, 1.44MB free space
BXDriveGeometry BXCDROMGeometry			= {2048, 1, 65535, 0};		//~650MB, no free space

//Media IDs used by _DOSBoxDriveFromPath:freeSpace:geometry:mediaID
const NSUInteger BXFloppyMediaID	= 0xF0;
const NSUInteger BXHardDiskMediaID	= 0xF8;
const NSUInteger BXCDROMMediaID		= BXHardDiskMediaID;

//Error constants returned by DriveManager::UnmountDrive.
enum {
	BXUnmountSuccess		= 0,
	BXUnmountLockedDrive	= 1,
	BXUnmountMultipleCDROMs	= 2
};

//Error constants returned by the cdromDrive class constructor.
//I can't be bothered going through all of them to give them proper names yet,
//but when I do then we'll generate NSError objects from them.
enum {
	BXMakeCDROMSuccess			= 0,
	BXMakeCDROMSuccessLimited	= 5,
};




@implementation BXEmulator (BXDOSFileSystem)

+ (NSArray *) executableTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
		@"com.microsoft.windows-executable",	//.exe
		@"com.microsoft.msdos-executable",		//.com
		@"com.microsoft.batch-file",			//.bat
	nil];
	return types;
}

+ (NSArray *) mountableImageTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
		@"public.iso-image",					//.iso
		@"com.apple.disk-image-cdr",			//.cdr
		@"com.goldenhawk.cdrwin-cuesheet",		//.cue
	nil];
	return types;
}
+ (NSArray *) mountableFolderTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
		@"public.directory",
	nil];
	return types;
}
+ (NSArray *) mountableTypes
{
	static NSArray *types = nil;
	if (!types) types = [[[self mountableImageTypes] arrayByAddingObjectsFromArray: [self mountableFolderTypes]] retain];
	return types;
}

//Todo: this could be done much more efficiently
+ (NSArray *) driveLetters
{
	static NSArray *letters = nil;
	if (!letters) letters = [[NSArray alloc] initWithObjects:
		@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I",
		@"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R",
		@"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z", nil];
	
	return letters;
}
+ (NSArray *) floppyDriveLetters
{
	static NSArray *letters = nil;
	if (!letters) letters = [[[self driveLetters] subarrayWithRange: NSMakeRange(0, 24)] retain];
	return letters;
}
+ (NSArray *) hardDriveLetters
{
	static NSArray *letters = nil;
	if (!letters) letters = [[[self driveLetters] subarrayWithRange: NSMakeRange(2, 22)] retain];
	return letters;
}


//Returns whether a specific folder is safe to mount from DOS
//This is used to restrict access to the root folder and library folders
//TODO: whitelist ~/Library/Cache/
+ (BOOL) pathIsSafeToMount: (NSString *)thePath
{
	//Fully resolve the path to eliminate any symlinks, tildes and backtracking
	NSString *resolvedPath		= [thePath stringByStandardizingPath];
	NSString *rootPath			= NSOpenStepRootDirectory();
	if ([resolvedPath isEqualToString: rootPath]) return NO;
	
	NSArray *restrictedPaths	= NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES);
	for (NSString *testPath in restrictedPaths) if ([resolvedPath hasPrefix: testPath]) return NO;
	
	return YES;
}

//Filesystem validation
//---------------------

//If the folder was restricted, print an error to the shell and deny access
//Todo: this assumes that the check is being called from the shell; we should instead populate an NSError with the error details and let the upstream context handle it
- (BOOL) shouldMountPath: (NSString *)thePath
{
	if (![[self class] pathIsSafeToMount: thePath])
	{
		NSString *errorMessage = NSLocalizedStringFromTable(
			@"Mounting system folders such as %@ is not permitted.",
			@"Shell", 
			@"Printed to the DOS shell when the user attempts to mount a system folder. %@ is the fully resolved folder path, which may not be the path they entered."
		);

		[self displayString: [NSString stringWithFormat: errorMessage, thePath]];
		return NO;
	}
	else return YES;
}


//Drive mounting and unmounting
//-----------------------------

- (BXDrive *) mountDrive: (BXDrive *)drive
{
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	BOOL isFolder;
	
	//File did not exist, don't continue mounting
	if (![manager fileExistsAtPath: [drive path] isDirectory: &isFolder]) return nil;
	
	BOOL isImage = !isFolder;

	NSString *driveLetter = [drive letter];

	//Choose an appropriate drive letter to mount it at, if one hasn't been specified
	if (!driveLetter) driveLetter = [self preferredLetterForDrive: drive];
	
	//No drive letters were available - do not attempt to mount
	//TODO: populate an NSError object also
	if (driveLetter == nil) return nil;
	
	
	DOS_Drive *DOSBoxDrive;
	NSUInteger index = [self _indexOfDriveLetter: driveLetter];
	NSString *path = [drive path];
	//The standardized path returned by BXDrive will not have a trailing slash, so add it ourselves
	if (isFolder) path = [path stringByAppendingString: @"/"];
	
	switch ([drive type])
	{
		case BXDriveCDROM:
			if (isImage)	DOSBoxDrive = [self _CDROMDriveFromImageAtPath: path forIndex: index];
			else			DOSBoxDrive = [self _CDROMDriveFromPath: path forIndex: index withAudio: [drive usesCDAudio]];
			break;
		case BXDriveHardDisk:
			DOSBoxDrive = [self _hardDriveFromPath: path freeSpace: [drive freeSpace]];
			break;
		case BXDriveFloppyDisk:
			DOSBoxDrive = [self _floppyDriveFromPath: path freeSpace: [drive freeSpace]];
			break;
	}
	
	//DOSBox successfully created the drive object
	if (DOSBoxDrive)
	{
		[self willChangeValueForKey: @"mountedDrives"];
		
		//Now, add it to the drive list
		[self _addDOSBoxDrive: DOSBoxDrive atIndex: index];
		//And set its label appropriately (unless its an image, which carry their own labels)
		if (!isImage)
		{
			const char *cLabel = [[drive label] cStringUsingEncoding: BXDirectStringEncoding];
			DOSBoxDrive->dirCache.SetLabel(cLabel, [drive isCDROM], false);
		}
		
		//Populate the drive with the settings we ended up using
		[drive setLetter: driveLetter];

		[self didChangeValueForKey: @"mountedDrives"];
		
		//Post a notification to whoever's listening
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
		[[[NSWorkspace sharedWorkspace] notificationCenter]
			postNotificationName: @"BXDriveDidMountNotification"
			object: self
			userInfo: userInfo];

		return drive;
	}
	else return nil;
}

- (BOOL) unmountDrive: (BXDrive *)drive
{
	if ([drive isInternal]) return NO;
	
	NSUInteger index	= [self _indexOfDriveLetter: [drive letter]];
	BOOL isCurrentDrive = (index == DOS_GetDefaultDrive());

	[self willChangeValueForKey: @"mountedDrives"];
	BOOL unmounted = [self _unmountDriveAtIndex: index];
	[self didChangeValueForKey: @"mountedDrives"];
	
	if (unmounted)
	{
		//If this was the drive we were on, recover by switching to Z drive
		if (isCurrentDrive) [self changeToDriveLetter: @"Z"];
		
		//Post a notification to whoever's listening
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
		[[[NSWorkspace sharedWorkspace] notificationCenter]
			postNotificationName: @"BXDriveDidUnmountNotification"
			object: self
			userInfo: userInfo];
	}
	return unmounted;
}

- (BOOL) unmountDriveAtLetter: (NSString *)letter
{	
	BXDrive *drive = [self driveAtLetter: letter];
	if (drive) return [self unmountDrive: drive];
	return NO;
}

- (BOOL) unmountDrivesForPath: (NSString *)path
{
	NSString *standardizedPath = [path stringByStandardizingPath];
	BOOL succeeded = NO;
	
	[self openQueue];
	for (BXDrive *drive in [self mountedDrives])
	{
		if ([[drive path] isEqualToString: standardizedPath])
			succeeded = [self unmountDrive: drive] || succeeded;
	}
	[self closeQueue];
	return succeeded;
}

- (void) refreshMountedDrives
{
	if ([self isExecuting])
	{
		for (NSUInteger i=0; i < DOS_DRIVES; i++)
		{
			if (Drives[i]) Drives[i]->EmptyCache();
		}
	}
}

- (NSString *) preferredLetterForDrive: (BXDrive *)drive
{
	NSArray *usedLetters = [self mountedDriveLetters];
	
	//TODO: try to ensure CD-ROM mounts are contiguous
	NSArray *letters;
	if ([drive isFloppy])	letters = [[self class] floppyDriveLetters];
	else					letters = [[self class] hardDriveLetters];

	//Scan for the first available drive letter that isn't already mounted
	for (NSString *letter in letters) if (![usedLetters containsObject: letter]) return letter;
	
	//Looks like all possible drive letters are mounted! bummer
	return nil;
}


//Drive and filesystem introspection
//----------------------------------

- (BXDrive *) currentDrive			{ return [self _driveAtIndex: DOS_GetDefaultDrive()]; }
- (NSString *) currentDriveLetter	{ return [[[self class] driveLetters] objectAtIndex: DOS_GetDefaultDrive()]; }
- (NSString *) currentWorkingDirectory
{
	return [NSString stringWithCString: Drives[DOS_GetDefaultDrive()]->curdir encoding: BXDirectStringEncoding];
}

- (NSArray *) mountedDrives
{
	NSArray *driveLetters	= [[self class] driveLetters];
	NSMutableArray *drives	= [NSMutableArray arrayWithCapacity: [driveLetters count]];
	
	for (NSString *letter in driveLetters)
	{
		BXDrive *drive = [self driveAtLetter: letter];
		if (drive) [drives addObject: drive];
	}
	return (NSArray *)drives;
}

- (NSArray *) mountedDriveLetters
{
	NSArray *possibleLetters	= [[self class] driveLetters]; 
	NSMutableArray *usedLetters	= [NSMutableArray arrayWithCapacity: DOS_DRIVES];
	for (NSUInteger i=0; i < DOS_DRIVES; i++)
	{
		if (Drives[i]) [usedLetters addObject: [possibleLetters objectAtIndex: i]];
	}
	return (NSArray *)usedLetters;
}

- (BXDrive *)driveAtLetter: (NSString *)driveLetter
{
	return [self _driveAtIndex: [self _indexOfDriveLetter: driveLetter]];
}

- (BOOL)driveExistsAtLetter: (NSString *)driveLetter
{
	NSUInteger index = [self _indexOfDriveLetter: driveLetter];
	if (Drives[index]) return YES;
	return NO;
}

- (NSUInteger) numDrives
{
	NSUInteger count;
	for (NSUInteger i=0; i < DOS_DRIVES; i++) if (Drives[i]) count++;
	return count;
}

- (BOOL) pathIsMountedAsDrive: (NSString *)path
{
	path = [path stringByStandardizingPath];
	for (BXDrive *drive in [self mountedDrives])
	{
		if ([[drive path] isEqualTo: path]) return YES;
	}
	return NO;
}

- (BOOL) pathIsDOSAccessible: (NSString *)path
{
	path = [path stringByStandardizingPath];
	for (BXDrive *drive in [self mountedDrives]) if ([drive exposesPath: path]) return YES;
	return NO;
}

- (BXDrive *) driveForPath: (NSString *)path
{
	path = [path stringByStandardizingPath];
	
	//Sort the drives by path depth, so that deeper mounts are picked over 'shallower' ones.
	//e.g. when MyGame.boxer and MyGame.boxer/MyCD.cdrom are both mounted, it should pick the latter.
	//Todo: filter this down to matching drives first, then do the sort, which would be quicker.
	NSArray *sortedDrives = [[self mountedDrives] sortedArrayUsingSelector:@selector(pathDepthCompare:)];
	
	for (BXDrive *drive in [sortedDrives reverseObjectEnumerator]) 
	{
		if ([drive exposesPath: path]) return drive;
	}
	return nil;
}

- (NSString *) DOSPathForPath: (NSString *)path
{
	BXDrive *drive = [self driveForPath: path];
	if (drive) return [self DOSPathForPath: path onDrive: drive];
	else return nil;
}

- (NSString *) DOSPathForPath: (NSString *)path onDrive: (BXDrive *)drive
{
	path = [path stringByStandardizingPath];

	//Start with the drive
	NSString *dosDrive = [NSString stringWithFormat: @"%@:", [drive letter], nil];
	
	//If the path is at the root of the drive, end there too.
	if ([path isEqualToString: [drive path]]) return dosDrive;
	
	//The path would not be accessible on this drive; give up before we go any further. 
	if (![drive exposesPath: path]) return nil;


	//To be extra sure we get this right, flush the drive caches before we look anything up
	[self refreshMountedDrives];
	
	NSString *basePath			= [drive path];
	NSMutableString *dosPath	= [NSMutableString stringWithCapacity: CROSS_LEN];
	
	NSArray *components			= [path pathComponents];
	NSUInteger i, numComponents	= [components count], startingPoint = [[basePath pathComponents] count];
	
	NSString *frankenPath, *fileName, *dosName;
	
	NSUInteger driveIndex = [self _indexOfDriveLetter: [drive letter]];
	
	for (i=startingPoint; i<numComponents; i++)
	{
		fileName = [components objectAtIndex: i];
		
		//TODO Optimisation: check if the filename is already DOS-safe (within 8.3 and only ASCII characters),
		//and if so then pass it on directly without doing a DOSBox long-filename lookup. 

		
		//Can you fucking believe this shit? DOSBox looks up host OS file paths using the full base path of the drive (in the host OS's filesystem notation) plus the *abbreviated 8.3 DOS filepath from then on*. So we append the dos path we've generated so far onto the base drive path and pass that frankensteinian concoction as the folder path we're trying to look up.
		frankenPath	= [[drive path] stringByAppendingString: dosPath];
		
		char buffer[CROSS_LEN] = {0};
		BOOL hasShortName = Drives[driveIndex]->dirCache.GetShortName(
			[frankenPath cStringUsingEncoding: BXDirectStringEncoding],
			[fileName cStringUsingEncoding: BXDirectStringEncoding],
			buffer);
	
		if (hasShortName)
			dosName = [NSString stringWithCString: (const char *)buffer encoding: BXDirectStringEncoding];
		else
			//If DOSBox didn't find a shorter name, it probably means the name is already short enough - just make sure it's
			//uppercased.
			//TODO: if DOSBox fails to find a filepath for some other reason, maybe we should still run the filename through our own makeDOSFilename: method to get a 'dos-like' filepath that might work. However, doing so would hide the failure, and make debugging it that much harder.
			dosName = [fileName uppercaseString];

		[dosPath appendFormat: @"/%@", dosName, nil];
	}
	return [dosDrive stringByAppendingString: dosPath];
}


//Methods for performing filesystem tasks
//---------------------------------------

- (BOOL) changeWorkingDirectoryToPath: (NSString *)dosPath
{
	BOOL changedPath = NO;
	
	[self openQueue];
	
	//If the path starts with a drive letter, switch to that first
	if ([dosPath length] >= 2 && [dosPath characterAtIndex: 1] == (unichar)':')
	{
		NSString *driveLetter = [dosPath substringToIndex: 1];
		//Snip off the drive letter from the front of the path
		dosPath = [dosPath substringFromIndex: 2];
		
		changedPath = [self changeToDriveLetter: driveLetter];
		//If the drive was not found, bail out early
		if (!changedPath)
		{
			[self closeQueue];
			return NO;
		}
	}

	if ([dosPath length])
	{
		char const * const dir = [dosPath cStringUsingEncoding: BXDirectStringEncoding];
		changedPath = (BOOL)DOS_ChangeDir(dir) || changedPath;
	}
	
	if (changedPath) [self setPromptNeedsDisplay: YES];
	
	[self closeQueue];
	return changedPath;
}

- (BOOL) changeToDriveLetter: (NSString *)driveLetter 
{
	BOOL changedPath = (BOOL)DOS_SetDrive([self _indexOfDriveLetter: driveLetter]);
	if (changedPath) [self setPromptNeedsDisplay: YES];
	return changedPath;
}

@end



//Internal methods (no touchy!)
@implementation BXEmulator (BXDOSFileSystemInternals)

//Used internally to match DOS drive letters to the DOSBox drive array
- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter
{
	NSUInteger index = [[[self class] driveLetters] indexOfObject: driveLetter];
	NSAssert1(index != NSNotFound,	@"driveLetter %@ passed to _indexOfDriveLetter: was not a valid DOS drive letter.", driveLetter);
	NSAssert2(index < DOS_DRIVES,	@"driveIndex %u derived from %@ in _indexOfDriveLetter: was beyond the range of DOSBox's drive array.", index, driveLetter);
	return index;
}

//Used internally to retrieve drives from DOSBox's Drives array
//TODO: split this into two functions, one to return the DOSBox drive object from an index and another to convert DOSBox drive objects into BXDrives.
- (BXDrive *)_driveAtIndex: (NSUInteger)index
{
	NSAssert1(index < DOS_DRIVES, @"index %u passed to _driveAtIndex was beyond the range of DOSBox's drive array.", index);
	if (Drives[index])
	{
		NSString *driveLetter	= [[[self class] driveLetters] objectAtIndex: index];
		NSString *path			= [NSString stringWithCString: Drives[index]->getSystemPath() encoding: BXDirectStringEncoding];
		
		if (![path length]) path = nil;	//Internal drives
		return [BXDrive driveFromPath: path atLetter: driveLetter];
	}
	else return nil;
}

//Register a new drive in DOS and add it to the drive list
//TODO: sanity-check assert that a drive at that index doesn't already exist
- (void) _addDOSBoxDrive: (DOS_Drive *)drive atIndex: (NSUInteger)index
{
	Drives[index] = drive;
	mem_writeb(Real2Phys(dos.tables.mediaid)+(index)*2, drive->GetMediaByte());
}

//Unmount a drive and clear references to it
- (BOOL) _unmountDriveAtIndex: (NSUInteger)index
{
	NSInteger result = DriveManager::UnmountDrive(index);
	if (result == BXUnmountSuccess)
	{
		Drives[index] = NULL;
		return YES;
	}
	else return NO;
}

//Create a new DOS_Drive CDROM from a path to a disc image
- (DOS_Drive *) _CDROMDriveFromImageAtPath: (NSString *)path forIndex: (NSUInteger)index
{
	MSCDEX_SetCDInterface(CDROM_USE_SDL, -1);
	
	char driveLetter		= index + 'A';
	const char *drivePath	= [path cStringUsingEncoding: BXDirectStringEncoding];
	
	NSInteger error;
	DOS_Drive *drive = new isoDrive(driveLetter, drivePath, BXCDROMMediaID, error);
	
	if (!(error == BXMakeCDROMSuccess || error == BXMakeCDROMSuccessLimited))
	{
		delete drive;
		return nil;
	}
	return drive;
}

//Create a new DOS_Drive CDROM from a path to a filesystem folder
- (DOS_Drive *) _CDROMDriveFromPath: (NSString *)path
						   forIndex: (NSUInteger)index
						  withAudio: (BOOL)useCDAudio
{
	BXDriveGeometry geometry = BXCDROMGeometry;
	
	NSInteger SDLCDNum = (useCDAudio) ? 0 : -1;
	MSCDEX_SetCDInterface(CDROM_USE_IOCTL_DIO, SDLCDNum);
	
	char driveLetter		= index + 'A'; //Oh to hell with it, I give up on petty lookups
	const char *drivePath	= [path cStringUsingEncoding: BXDirectStringEncoding];
	
	NSInteger error;
	DOS_Drive *drive = new cdromDrive(
									  driveLetter,
									  drivePath,
									  geometry.bytesPerSector,
									  geometry.sectorsPerCluster,
									  geometry.numClusters,
									  geometry.freeClusters,
									  BXCDROMMediaID,
									  error);
	
	if (!(error == BXMakeCDROMSuccess || error == BXMakeCDROMSuccessLimited))
	{
		delete drive;
		return nil;
	}
	return drive;
}

//Create a new DOS_Drive hard disk from a path to a filesystem folder
- (DOS_Drive *) _hardDriveFromPath: (NSString *)path freeSpace: (NSInteger)freeSpace
{
	return [self _DOSBoxDriveFromPath: path
							freeSpace: freeSpace
							 geometry: BXHardDiskGeometry
							  mediaID: BXHardDiskMediaID];
}

//Create a new DOS_Drive floppy disk from a path to a filesystem folder
- (DOS_Drive *) _floppyDriveFromPath: (NSString *)path freeSpace: (NSInteger)freeSpace
{
	return [self _DOSBoxDriveFromPath: path
							freeSpace: freeSpace
							 geometry: BXFloppyDiskGeometry
							  mediaID: BXFloppyMediaID];
}

//Internal DOS_Drive localdrive function for the two wrapper methods above
- (DOS_Drive *)	_DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)geometry
							 mediaID: (NSUInteger)mediaID
{
	if (freeSpace != BXDefaultFreeSpace)
	{
		NSUInteger bytesPerCluster = (geometry.bytesPerSector * geometry.sectorsPerCluster);
		geometry.freeClusters = freeSpace / bytesPerCluster;
	}
	
	const char *drivePath = [path cStringUsingEncoding: BXDirectStringEncoding];
	return new localDrive(
						  drivePath,
						  geometry.bytesPerSector,
						  geometry.sectorsPerCluster,
						  geometry.numClusters,
						  geometry.freeClusters,
						  mediaID);
}

@end




//Bridge functions
//----------------
//DOSBox uses these to call relevant methods on the current Boxer emulation context


//Whether or not to allow the specified path to be mounted.
//Called by MOUNT::Run in DOSBox's dos/dos_programs.cpp.
bool boxer_willMountPath(const char *pathStr)
{
	NSString *thePath = [[NSFileManager defaultManager]
						stringWithFileSystemRepresentation: pathStr
						length: strlen(pathStr)];
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator shouldMountPath: thePath];
}