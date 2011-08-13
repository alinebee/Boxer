/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"

#import "BXDrive.h"
#import "NSString+BXPaths.h"
#import "BXGameProfile.h"
#import "BXPackage.h"
#import "RegexKitLite.h"

#import "dos_inc.h"
#import "dos_system.h"
#import "drives.h"
#import "cdrom.h"

#import "NSWorkspace+BXMountedVolumes.h"



#pragma mark -
#pragma mark Constants

NSString * const BXDOSBoxUnmountErrorDomain  = @"BXDOSBoxUnmountErrorDomain";
NSString * const BXDOSBoxMountErrorDomain    = @"BXDOSBoxMountErrorDomain";


//Drive geometry constants passed to _DOSBoxDriveFromPath:freeSpace:geometry:mediaID:error:
BXDriveGeometry BXHardDiskGeometry		= {512, 127, 16383, 4031};	//~1GB, ~250MB free space
BXDriveGeometry BXFloppyDiskGeometry	= {512, 1, 2880, 2880};		//1.44MB, 1.44MB free space
BXDriveGeometry BXCDROMGeometry			= {2048, 1, 65535, 0};		//~650MB, no free space


#pragma mark -
#pragma mark Externs

//Defined in dos_files.cpp
extern DOS_File * Files[DOS_FILES];
extern DOS_Drive * Drives[DOS_DRIVES];

//Defined in dos_mscdex.cpp
void MSCDEX_SetCDInterface(int intNr, int forceCD);




@implementation BXEmulator (BXDOSFileSystem)

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
+ (NSArray *) CDROMDriveLetters
{
	static NSArray *letters = nil;
	if (!letters) letters = [[[self driveLetters] subarrayWithRange: NSMakeRange(3, 22)] retain];
	return letters;	
}


+ (NSSet *) dosFileExclusions
{
	static NSSet *exclusions = nil;
	if (!exclusions) exclusions = [[NSSet alloc] initWithObjects:
								   [BXConfigurationFileName stringByAppendingPathExtension: BXConfigurationFileExtension],
								   [BXGameInfoFileName stringByAppendingPathExtension: BXGameInfoFileExtension],
								   BXTargetSymlinkName,
								   @"Icon\r",
								   nil];
								   
	return exclusions;
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


#pragma mark -
#pragma mark Drive mounting and unmounting

- (BXDrive *) mountDrive: (BXDrive *)drive error: (NSError **)outError
{
    //This is not permitted and indicates a programming error
    NSAssert([self isExecuting], @"mountDrive:error: called while emulator is not running.");
    
    if (outError) *outError = nil;
    
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSString *mountPath = [drive mountPoint];
	BOOL isFolder;
	
	//File does not exist or cannot be read, don't continue mounting
	if (![manager fileExistsAtPath: mountPath isDirectory: &isFolder] ||
        ![manager isReadableFileAtPath: mountPath])
    {
        if (outError) *outError = [BXEmulatorCouldNotReadDriveError errorWithDrive: drive];
        return nil;
    }
	
	BOOL isImage = !isFolder;

	NSString *driveLetter = [drive letter];
	NSString *driveLabel = [drive label];
	
	
	//Choose an appropriate drive letter to mount the drive at,
	//if one hasn't been specified.
	if (!driveLetter) driveLetter = [self preferredLetterForDrive: drive];
	
	//If no drive letters were available, do not continue.
	if (driveLetter == nil)
    {
        if (outError) *outError = [BXEmulatorOutOfDriveLettersError errorWithDrive: drive];
        return nil;
    }
    //Don't continue if there's already a drive at this letter either.
    else if ([self driveAtLetter: driveLetter] != nil)
    {
        if (outError) *outError = [BXEmulatorDriveLetterOccupiedError errorWithDrive: drive];
        return nil;
    }
    
    //If we got this far, then we're ready to let DOSBox have a crack at the drive.
	
	
	DOS_Drive *DOSBoxDrive = NULL;
	NSUInteger index = [self _indexOfDriveLetter: driveLetter];
    
	//The standardized path returned by BXDrive will not have a trailing slash,
    //but DOSBox expects it, so add it ourselves
	if (isFolder) mountPath = [mountPath stringByAppendingString: @"/"];
	
    NSError *mountError = nil;
    if (isImage)
    {
        switch ([drive type])
        {
            case BXDriveCDROM:
                DOSBoxDrive = [self _CDROMDriveFromImageAtPath: mountPath
                                                      forIndex: index
                                                         error: &mountError];
                break;
            case BXDriveHardDisk:
                DOSBoxDrive = [self _hardDriveFromImageAtPath: mountPath
                                                        error: &mountError];
                break;
            case BXDriveFloppyDisk:
                DOSBoxDrive = [self _floppyDriveFromImageAtPath: mountPath
                                                          error: &mountError];
                break;
        }
    }
    else
    {
        switch ([drive type])
        {
            case BXDriveCDROM:
                DOSBoxDrive = [self _CDROMDriveFromPath: mountPath
                                               forIndex: index
                                              withAudio: [drive usesCDAudio]
                                                  error: &mountError];
                break;
                
            case BXDriveHardDisk:
                DOSBoxDrive = [self _hardDriveFromPath: mountPath
                                             freeSpace: [drive freeSpace]
                                                 error: &mountError];
                break;
                
            case BXDriveFloppyDisk:
                DOSBoxDrive = [self _floppyDriveFromPath: mountPath
                                               freeSpace: [drive freeSpace]
                                                   error: &mountError];
                break;
        }
    }
	
	//DOSBox successfully created the drive object
	if (DOSBoxDrive)
	{
		//Now add the drive to DOSBox's own drive list
		if ([self _addDOSBoxDrive: DOSBoxDrive atIndex: index])
		{
			//And set its label appropriately (unless its an image, which carry their own labels)
			if (!isImage && driveLabel)
			{
				const char *cLabel = [driveLabel cStringUsingEncoding: BXDirectStringEncoding];
				if (cLabel)
					DOSBoxDrive->SetLabel(cLabel, [drive isCDROM], false);
			}
			
			//Populate the drive with the settings we ended up using, and add the drive to our own drives cache
			[drive setLetter: driveLetter];
			[drive setDOSBoxLabel: [NSString stringWithCString: DOSBoxDrive->GetLabel()
                                                      encoding: BXDirectStringEncoding]];
			[self _addDriveToCache: drive];
			
			//Post a notification to whoever's listening
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
            
			[self _postNotificationName: @"BXDriveDidMountNotification"
					   delegateSelector: @selector(emulatorDidMountDrive:)
							   userInfo: userInfo];
			
			return drive;
		}
		else
		{
            //The only reason this can fail currently is if another drive has been inserted at the same letter.
            //We check for this and fail earlier, but this could possibly still happen if there's a race condition.
            //TODO: let _addDOSBoxDrive:atIndex: populate an error.
            if (outError) *outError = [BXEmulatorDriveLetterOccupiedError errorWithDrive: drive];
            
			delete DOSBoxDrive;
			return nil;
		}
	}
	else
    {
        //Figure out what went wrong, and transform it into a more presentable error type.
        if (outError)
        {
            if ([[mountError domain] isEqualToString: BXDOSBoxMountErrorDomain])
            {
                switch ([mountError code])
                {
                    case BXDOSBoxMountNonContiguousCDROMDrives:
                        *outError = [BXEmulatorNonContiguousDrivesError errorWithDrive: drive];
                        break;
                    case BXDOSBoxMountCouldNotReadSource:
                        *outError = [BXEmulatorCouldNotReadDriveError errorWithDrive: drive];
                        break;
                    case BXDOSBoxMountTooManyCDROMDrives:
                        *outError = [BXEmulatorOutOfCDROMDrivesError errorWithDrive: drive];
                        break;
                    case BXDOSBoxMountInvalidImageFormat:
                        *outError = [BXEmulatorInvalidImageError errorWithDrive: drive];
                        break;
                    default:
                        *outError = mountError;
                }
            }
            else *outError = mountError;
        }
        return nil;
    }
}

- (BOOL) unmountDrive: (BXDrive *)drive error: (NSError **)outError
{
    //This is not permitted and indicates a programming error
    NSAssert([self isExecuting], @"unmountDrive:error: called while emulator is not running.");
    
	if ([drive isInternal] || [drive isLocked])
    {
        if (outError) *outError = [BXEmulatorDriveLockedError errorWithDrive: drive];
        return NO;
    }
	
	NSUInteger index	= [self _indexOfDriveLetter: [drive letter]];
	BOOL isCurrentDrive = (index == DOS_GetDefaultDrive());

    NSError *unmountError = nil;
	BOOL unmounted = [self _unmountDOSBoxDriveAtIndex: index
                                                error: &unmountError];
	
	if (unmounted)
	{
		//If this was the drive we were on, recover by switching to Z drive
		if (isCurrentDrive && [self isAtPrompt]) [self changeToDriveLetter: @"Z"];
		
		//Remove the drive from our drive cache
		[self _removeDriveFromCache: drive];
		
		//Post a notification to whoever's listening
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
		[self _postNotificationName: @"BXDriveDidUnmountNotification"
				   delegateSelector: @selector(emulatorDidUnmountDrive:)
						   userInfo: userInfo];
	}
    else if (outError)
    {   
        //Transform DOSBox's error codes into our own
        if ([[unmountError domain] isEqualToString: BXDOSBoxUnmountErrorDomain])
        {
            switch ([unmountError code])
            {
                case BXDOSBoxUnmountLockedDrive:
                    *outError = [BXEmulatorDriveLockedError errorWithDrive: drive];
                    break;
                case BXDOSBoxUnmountNonContiguousCDROMDrives:
                    *outError = [BXEmulatorNonContiguousDrivesError errorWithDrive: drive];
                    break;
                default:
                    *outError = unmountError;
            }
        }
        else *outError = unmountError;
    }
	return unmounted;
}

- (BOOL) unmountDriveAtLetter: (NSString *)letter error: (NSError **)outError
{	
	BXDrive *drive = [self driveAtLetter: letter];
	if (drive) return [self unmountDrive: drive error: outError];
	return NO;
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
	NSArray *usedLetters = [driveCache allKeys];
	
	//TODO: try to ensure CD-ROM mounts are contiguous
	NSArray *letters;
	if ([drive isFloppy])		letters = [[self class] floppyDriveLetters];
	else if ([drive isCDROM])	letters = [[self class] CDROMDriveLetters];
	else						letters = [[self class] hardDriveLetters];

	//Scan for the first available drive letter that isn't already mounted
	for (NSString *letter in letters) if (![usedLetters containsObject: letter]) return letter;
	
	//Looks like all possible drive letters are mounted! bummer
	return nil;
}


#pragma mark -
#pragma mark Drive and filesystem introspection

- (NSArray *) mountedDrives
{
	return [driveCache allValues];
}

- (BXDrive *) driveAtLetter: (NSString *)driveLetter
{
	return [driveCache objectForKey: driveLetter];
}

- (BOOL) driveInUseAtLetter: (NSString *)driveLetter
{
	if ([self processPath])
	{
		NSString *processDriveLetter = [[self processPath] substringToIndex: 1];
		if ([driveLetter isEqualToString: processDriveLetter]) return YES;
	}
	return [self _DOSBoxDriveInUseAtIndex: [self _indexOfDriveLetter: driveLetter]];
}

- (BOOL) pathIsMountedAsDrive: (NSString *)path
{
	for (BXDrive *drive in [driveCache objectEnumerator])
	{
		if ([drive representsPath: path]) return YES;
	}
	return NO;
}

- (BOOL) pathIsDOSAccessible: (NSString *)path
{
	for (BXDrive *drive in [driveCache objectEnumerator])
	{
		if ([drive exposesPath: path]) return YES;
	}
	return NO;
}

- (BOOL) pathExistsInDOS: (NSString *)path
{
    NSString *dosPath = [self DOSPathForPath: path];
    if (!dosPath) return NO;
    
    return [self DOSPathExists: dosPath];
}

- (BOOL) DOSPathExists: (NSString *)dosPath
{
    DOS_Drive *dosDrive;
    
	dosPath = [dosPath stringByReplacingOccurrencesOfString: @"/" withString: @"\\"];
    
    //If the path starts with a drive letter, pop it off
	if ([dosPath length] >= 2 && [dosPath characterAtIndex: 1] == (unichar)':')
	{
		NSString *driveLetter = [dosPath substringToIndex: 1];
		//Snip off the drive letter from the front of the path
		dosPath = [dosPath substringFromIndex: 2];
		
        NSUInteger driveIndex = [self _indexOfDriveLetter: driveLetter];
        dosDrive = Drives[driveIndex];
	}
    else dosDrive = Drives[DOS_GetDefaultDrive()];
    
    if (!dosDrive) return NO;
    
    //If the path was empty (e.g. nothing more than a drive letter)
    //then it represents the current or root path, so yes it exists
    if (![dosPath length]) return YES;
	
    //Otherwise, ask the drive itself
    return dosDrive->FileExists([dosPath cStringUsingEncoding: BXDirectStringEncoding]);
}


- (BXDrive *) driveForPath: (NSString *)path
{	
	//Sort the drives by path depth, so that deeper mounts are picked over 'shallower' ones.
	//e.g. when MyGame.boxer and MyGame.boxer/MyCD.cdrom are both mounted, it should pick the latter.
	//Todo: filter this down to matching drives first, then do the sort, which would be quicker.
	NSArray *sortedDrives = [[driveCache allValues] sortedArrayUsingSelector: @selector(pathDepthCompare:)];
	
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
	if (![self isExecuting]) return nil;
	
	NSString *subPath = [drive relativeLocationOfPath: path];
	
	//The path is not be accessible on this drive; give up before we go any further. 
	if (!subPath) return nil;
	
	NSString *dosDrive = [NSString stringWithFormat: @"%@:", [drive letter], nil];
	
	//If the path is at the root of the drive, bail out now.
	if (![subPath length]) return dosDrive;

	NSString *basePath			= [drive mountPoint];
	NSArray *components			= [subPath pathComponents];
	
	NSUInteger driveIndex	= [self _indexOfDriveLetter: [drive letter]];
	DOS_Drive *DOSBoxDrive	= Drives[driveIndex];
	if (!DOSBoxDrive) return nil;
	
	//To be sure we get this right, flush the drive cache before we look anything up
	DOSBoxDrive->EmptyCache();

	NSMutableString *dosPath = [NSMutableString stringWithCapacity: CROSS_LEN];
	
	for (NSString *fileName in components)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		NSString *frankenPath = [basePath stringByAppendingString: dosPath];
		NSString *dosName = nil;
		
		char buffer[CROSS_LEN] = {0};
		const char *cFrankenPath	= [frankenPath cStringUsingEncoding: BXDirectStringEncoding];
		const char *cFileName		= [fileName cStringUsingEncoding: BXDirectStringEncoding];
		
		BOOL hasShortName = NO;
		//If the file paths could not be encoded to acceptable C strings,
		//don't feed them to DOSBox's functions
		if (cFrankenPath && cFileName)
		{
			hasShortName = DOSBoxDrive->getShortName([frankenPath cStringUsingEncoding: BXDirectStringEncoding],
													 [fileName cStringUsingEncoding: BXDirectStringEncoding],
													 buffer);
		}
			
		if (hasShortName)
		{
			dosName = [NSString stringWithCString: (const char *)buffer encoding: BXDirectStringEncoding];
		}
		else
		{
			//TODO: if filename is longer than 8.3, crop and append ~1 as a last-ditch guess.
			dosName = [fileName uppercaseString];
		}
		
		[dosPath appendFormat: @"/%@", dosName, nil];
		
		[pool release];
	}
	return [dosDrive stringByAppendingString: dosPath];
}

- (BXDrive *) currentDrive { return [driveCache objectForKey: [self currentDriveLetter]]; }
- (NSString *) currentDriveLetter
{
	if ([self isExecuting])
	{
		return [[[self class] driveLetters] objectAtIndex: DOS_GetDefaultDrive()];
	}
	else return nil;
}

- (NSString *) currentDirectory
{
	if ([self isExecuting])
	{
		return [NSString stringWithCString: Drives[DOS_GetDefaultDrive()]->curdir encoding: BXDirectStringEncoding];
	}
	else return nil;
}

- (NSString *) pathOfCurrentDirectory
{
	if ([self isExecuting])
	{
		DOS_Drive *currentDOSBoxDrive = Drives[DOS_GetDefaultDrive()];
		
		NSString *localPath	= [self _filesystemPathForDOSPath: currentDOSBoxDrive->curdir onDOSBoxDrive: currentDOSBoxDrive];
		if (localPath) return localPath;
		
		//If no accurate local path could be determined, then return the source path of the current drive instead 
		else return [[self currentDrive] path];		
	}
	else return nil;
}

- (NSString *) pathForDOSPath: (NSString *)path
{
	if ([self isExecuting])
	{
		const char *dosPath = [path cStringUsingEncoding: BXDirectStringEncoding];
		//If the path couldn't be encoded successfully, don't do further lookups
		if (!dosPath) return nil;
		
		char fullPath[DOS_PATHLENGTH];
		Bit8u driveIndex;
		BOOL resolved = DOS_MakeName(dosPath, fullPath, &driveIndex);

		if (resolved)
		{
			DOS_Drive *dosboxDrive = Drives[driveIndex];
			NSString *localPath	= [self _filesystemPathForDOSPath: fullPath onDOSBoxDrive: dosboxDrive];
			
			if (localPath) return localPath;
			else
			{
				BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
				return [drive path];
			}			
		}
		else return nil;
	}
	else return nil;
}

@end


#pragma mark -
#pragma mark Private methods

@implementation BXEmulator (BXDOSFileSystemInternals)

#pragma mark -
#pragma mark Translating between Boxer and DOSBox drives

//Used internally to match DOS drive letters to the DOSBox drive array
- (NSUInteger)_indexOfDriveLetter: (NSString *)driveLetter
{
	NSUInteger index = [[[self class] driveLetters] indexOfObject: [driveLetter uppercaseString]];
	NSAssert1(index != NSNotFound,	@"driveLetter %@ passed to _indexOfDriveLetter: was not a valid DOS drive letter.", driveLetter);
	NSAssert2(index < DOS_DRIVES,	@"driveIndex %u derived from %@ in _indexOfDriveLetter: was beyond the range of DOSBox's drive array.", index, driveLetter);
	return index;
}

- (NSString *)_driveLetterForIndex: (NSUInteger)index
{
	NSAssert1(index < [[[self class] driveLetters] count],
			  @"index %u passed to _driveLetterForIndex: was beyond the range of available drive letters.", index);
	return [[[self class] driveLetters] objectAtIndex: index];
}

//Returns the Boxer drive that matches the specified DOSBox drive, or nil if no drive was found
- (BXDrive *)_driveMatchingDOSBoxDrive: (DOS_Drive *)dosDrive
{
	NSUInteger i;
	for (i=0; i < DOS_DRIVES; i++)
	{
		if (Drives[i] == dosDrive)
		{
			return [driveCache objectForKey: [self _driveLetterForIndex: i]];
		}
	}
    return nil;
}

- (DOS_Drive *)_DOSBoxDriveMatchingDrive: (BXDrive *)drive
{
	NSUInteger index = [self _indexOfDriveLetter: [drive letter]];
	if (Drives[index]) return Drives[index];
	else return NULL;
}

- (NSString *)_filesystemPathForDOSPath: (const char *)dosPath onDOSBoxDrive: (DOS_Drive *)dosboxDrive
{	
	localDrive *localDOSBoxDrive = dynamic_cast<localDrive *>(dosboxDrive);
	if (localDOSBoxDrive)
	{
		char filePath[CROSS_LEN];
		localDOSBoxDrive->GetSystemFilename(filePath, (char const * const)dosPath);
		NSString *thePath = [[NSFileManager defaultManager]
							 stringWithFileSystemRepresentation: filePath
							 length: strlen(filePath)];
		
		return [thePath stringByStandardizingPath];
	}
	//We can't return a system file path for non-local drives
	else return nil;
}

#pragma mark -
#pragma mark Adding and removing new DOSBox drives


- (NSUInteger) _indexOfDOSBoxDrive: (DOS_Drive *)drive
{
	NSUInteger i;
	for (i=0; i < DOS_DRIVES; i++)
	{
		if (Drives[i] == drive) return i;
	}
	return NSNotFound;
}

//Registers a new drive with DOSBox and adds it to the drive list.
- (BOOL) _addDOSBoxDrive: (DOS_Drive *)drive
                 atIndex: (NSUInteger)index
{
	NSAssert1(index < DOS_DRIVES, @"index %u passed to _addDOSBoxDrive was beyond the range of DOSBox's drive array.", index);
	
	//There was already a drive at that index, bail out
	//TODO: populate an NSError object as well?
	if (Drives[index]) return NO;
	
	Drives[index] = drive;
	mem_writeb(Real2Phys(dos.tables.mediaid)+(index)*2, drive->GetMediaByte());
	
	return YES;
}

//Unmounts the DOSBox drive at the specified index and clears any references to the drive.
- (BOOL) _unmountDOSBoxDriveAtIndex: (NSUInteger)index
                              error: (NSError **)outError
{
	//The specified drive is not mounted, don't continue
    //(We don't treat this as an error situation either.)
	if (!Drives[index]) return NO;
	
    NSInteger result = DriveManager::UnmountDrive(index);
	if (result == BXDOSBoxUnmountSuccess)
	{
        //Close any files that DOSBox had open on this drive after unmounting it
        //TODO: port this code back to DOSBox itself, as it will not currently occur
        //if user unmounts a drive with the MOUNT command (not that this usually matters,
        //since there should be no open files while at the commandline, but still)
        int i;
        for (i=0; i<DOS_FILES; i++)
        {
            if (Files[i] && Files[i]->GetDrive() == index)
            {
                //DOS_File->GetDrive() returns 0 for the special CON system file,
                //which also corresponds to the drive index for A, so make sure we don't
                //close this by mistake.
                if (index == 0 && !strcmp(Files[i]->GetName(), "CON")) continue;
                
                //Code copy-pasted from localDrive::FileUnlink in drive_local.cpp
                //Only relevant for local drives, but harmless to perform on other types of drives.
                while (Files[i]->IsOpen())
                {
                    Files[i]->Close();
                    if (Files[i]->RemoveRef() <= 0) break;
                }
            }
        }
        
		Drives[index] = NULL;
		return YES;
	}
	else
    {
        if (outError) *outError = [NSError errorWithDomain: BXDOSBoxUnmountErrorDomain
                                                      code: result
                                                  userInfo: nil];
        return NO;
    }
}


//Generates a BXDrive object from a DOSBox drive entry.
- (BXDrive *)_driveFromDOSBoxDriveAtIndex: (NSUInteger)index
{
	NSAssert1(index < DOS_DRIVES, @"index %u passed to _driveFromDOSBoxDriveAtIndex was beyond the range of DOSBox's drive array.", index);
	if (Drives[index])
	{
		NSString *driveLetter	= [[[self class] driveLetters] objectAtIndex: index];
		NSString *path			= [NSString stringWithCString: Drives[index]->getSystemPath() encoding: BXDirectStringEncoding];
		NSString *label			= [NSString stringWithCString: Drives[index]->GetLabel() encoding: BXDirectStringEncoding];
		
		BXDrive *drive;
		//TODO: detect the specific type of drive here!
		//Requires drive-size heuristics, or keeping track of drive type in MOUNT/IMGMOUNT
		if (![path length])
		{
			drive = [BXDrive internalDriveAtLetter: driveLetter];
		}
		else
		{
			//Have a decent crack at resolving relative file paths
			if (![path isAbsolutePath])
			{
				path = [[self basePath] stringByAppendingPathComponent: path];
			}
			drive = [BXDrive driveFromPath: [path stringByStandardizingPath] atLetter: driveLetter];
		}
		[drive setLabel: label];
		return drive;
	}
	else return nil;
}

//Create a new DOS_Drive CDROM from a path to a disc image.
- (DOS_Drive *) _CDROMDriveFromImageAtPath: (NSString *)path
                                  forIndex: (NSUInteger)index
                                     error: (NSError **)outError
{
	MSCDEX_SetCDInterface(CDROM_USE_SDL, -1);
	
	char driveLetter		= index + 'A';
	const char *drivePath	= [path cStringUsingEncoding: BXDirectStringEncoding];
	//If the path couldn't be encoded, don't attempt to go further
	if (!drivePath) return nil;
	
	int errorCode = BXDOSBoxMountUnknownError;
	DOS_Drive *drive = new isoDrive(driveLetter, drivePath, BXCDROMMediaID, errorCode);
	
	if (errorCode == BXDOSBoxMountSuccess || errorCode == BXDOSBoxMountSuccessCDROMLimited)
	{
        return drive;
    }
    else
    {
		delete drive;
     
        if (outError) *outError = [NSError errorWithDomain: BXDOSBoxMountErrorDomain
                                                      code: errorCode
                                                  userInfo: nil];
        
        return nil;
	}
	return drive;
}

//Create a new DOS_Drive floppy from a path to a raw disk image.
- (DOS_Drive *) _floppyDriveFromImageAtPath: (NSString *)path
                                      error: (NSError **)outError
{	
	const char *drivePath = [path cStringUsingEncoding: BXDirectStringEncoding];
	//If the path couldn't be encoded, don't attempt to go further
	if (!drivePath) return nil;
	
	fatDrive *drive = new fatDrive(drivePath, 0, 0, 0, 0, 0);
	if (!drive || !drive->created_successfully)
    {
        delete drive;
    
        //Assume this is always a corrupted-image problem
        if (outError) *outError = [NSError errorWithDomain: BXDOSBoxMountErrorDomain
                                                      code: BXDOSBoxMountInvalidImageFormat
                                                  userInfo: nil];
        
        return nil;
    }
	return (DOS_Drive *)drive;
}

//Create a new DOS_Drive floppy from a path to a raw disk image.
//Currently unimplemented as this requires data about the
//volume layout of the image.
- (DOS_Drive *) _hardDriveFromImageAtPath: (NSString *)path
                                    error: (NSError **)outError
{
    if (outError) *outError = [NSError errorWithDomain: BXDOSBoxMountErrorDomain
                                                  code: BXDOSBoxMountInvalidImageFormat
                                              userInfo: nil];
    return nil;
}

//Create a new DOS_Drive CDROM from a path to a filesystem folder.
- (DOS_Drive *) _CDROMDriveFromPath: (NSString *)path
						   forIndex: (NSUInteger)index
						  withAudio: (BOOL)useCDAudio
                              error: (NSError **)outError
{
	BXDriveGeometry geometry = BXCDROMGeometry;
	 
	NSInteger SDLCDNum = -1;
	
	//Check that any audio CDs are actually present before enabling CD audio:
	//this fixes Warcraft II's copy protection, which will fail if audio tracks
	//are reported to be present but cannot be found.
	//IMPLEMENTATION NOTE: we can't just rely on SDL_CDNumDrives(), because that
	//reports a generic CD device on OS X even when none is present.
	if (useCDAudio && SDL_CDNumDrives() > 0)
	{
		NSArray *audioVolumes = [[NSWorkspace sharedWorkspace] mountedVolumesOfType: audioCDVolumeType];
		if ([audioVolumes count] > 0)
		{
			//NOTE: SDL's CD audio API for OS X only ever exposes one CD, which will be #0.
			SDLCDNum = 0;
		}
	}
	
	//NOTE: ioctl is currently unimplemented for OS X in DOSBox 0.74, so this will always fall back to SDL.
	MSCDEX_SetCDInterface(CDROM_USE_IOCTL_DIO, SDLCDNum);
	
	char driveLetter		= index + 'A';
	const char *drivePath	= [path cStringUsingEncoding: BXDirectStringEncoding];
	//If the path couldn't be encoded, don't attempt to go further
	if (!drivePath) return nil;
	
	int errorCode = BXDOSBoxMountUnknownError;
	DOS_Drive *drive = new cdromDrive(driveLetter,
									  drivePath,
									  geometry.bytesPerSector,
									  geometry.sectorsPerCluster,
									  geometry.numClusters,
									  geometry.freeClusters,
									  BXCDROMMediaID,
									  errorCode);
	
    if (errorCode == BXDOSBoxMountSuccess || errorCode == BXDOSBoxMountSuccessCDROMLimited)
    {
        return drive;
    }
    else
    {
        delete drive;
        
        if (outError)
            *outError = [NSError errorWithDomain: BXDOSBoxMountErrorDomain
                                            code: errorCode
                                        userInfo: nil];
		
		return nil;
	}
}

//Create a new DOS_Drive hard disk from a path to a filesystem folder.
- (DOS_Drive *) _hardDriveFromPath: (NSString *)path
                         freeSpace: (NSInteger)freeSpace
                             error: (NSError **)outError
{
	return [self _DOSBoxDriveFromPath: path
							freeSpace: freeSpace
							 geometry: BXHardDiskGeometry
							  mediaID: BXHardDiskMediaID
                                error: outError];
}

//Create a new DOS_Drive floppy disk from a path to a filesystem folder.
- (DOS_Drive *) _floppyDriveFromPath: (NSString *)path
                           freeSpace: (NSInteger)freeSpace
                               error: (NSError **)outError
{
	return [self _DOSBoxDriveFromPath: path
							freeSpace: freeSpace
							 geometry: BXFloppyDiskGeometry
							  mediaID: BXFloppyMediaID
                                error: outError];
}

//Internal DOS_Drive localdrive function for the two wrapper methods above
- (DOS_Drive *)	_DOSBoxDriveFromPath: (NSString *)path
						   freeSpace: (NSInteger)freeSpace
							geometry: (BXDriveGeometry)geometry
							 mediaID: (NSUInteger)mediaID
                               error: (NSError **)outError
{
	if (freeSpace != BXDefaultFreeSpace)
	{
		NSUInteger bytesPerCluster = (geometry.bytesPerSector * geometry.sectorsPerCluster);
		geometry.freeClusters = freeSpace / bytesPerCluster;
	}
	
	const char *drivePath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath: path];
	
    //NOTE: as far as DOSBox is concerned there's actually nothing that can go wrong here,
    //so outError goes unused.
	return new localDrive(drivePath,
						  geometry.bytesPerSector,
						  geometry.sectorsPerCluster,
						  geometry.numClusters,
						  geometry.freeClusters,
						  mediaID);
}



//Synchronizes Boxer's mounted drive cache with DOSBox's drive array,
//adding new drives and removing old drives as necessary.
- (void) _syncDriveCache
{
	NSDictionary *userInfo;
	NSUInteger i;
	
	for (i=0; i < DOS_DRIVES; i++)
	{
		NSString *letter	= [self _driveLetterForIndex: i];
		BXDrive *drive		= [driveCache objectForKey: letter];
		
		//A drive exists in DOSBox that we don't have a record of yet, add it to our cache
		if (Drives[i] && !drive)
		{
			drive = [self _driveFromDOSBoxDriveAtIndex: i];
			[self _addDriveToCache: drive];
			
			//Post a notification to whoever's listening
			userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
			[self _postNotificationName: @"BXDriveDidMountNotification"
					   delegateSelector: @selector(emulatorDidMountDrive:)
							   userInfo: userInfo];
		}
		//A drive no longer exists in DOSBox which we have a leftover record for, remove it
		else if (!Drives[i] && drive)
		{
			[self _removeDriveFromCache: drive];
			
			//Post a notification to whoever's listening
			userInfo = [NSDictionary dictionaryWithObject: drive forKey: @"drive"];
			[self _postNotificationName: @"BXDriveDidUnmountNotification"
					   delegateSelector: @selector(emulatorDidUnmountDrive:)
							   userInfo: userInfo];
		}
	}
}

- (void) _addDriveToCache: (BXDrive *)drive
{
	[self willChangeValueForKey: @"mountedDrives"];
	[driveCache setObject: drive forKey: [drive letter]];
	[self didChangeValueForKey: @"mountedDrives"];
}

- (void) _removeDriveFromCache: (BXDrive *)drive
{
	[self willChangeValueForKey: @"mountedDrives"];
	[driveCache removeObjectForKey: [drive letter]];
	[self didChangeValueForKey: @"mountedDrives"];
}

- (void) _didCreateFileAtPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive
{
	BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
	//Post a notification to whoever's listening
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  filePath, @"path",
							  drive, @"drive",
							  nil];
	
	[self _postNotificationName: BXEmulatorDidCreateFileNotification
			   delegateSelector: @selector(emulatorDidCreateFile:)
					   userInfo: userInfo];	
}

- (void) _didRemoveFileAtPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive
{
	BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
	//Post a notification to whoever's listening
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  filePath, @"path",
							  drive, @"drive",
							  nil];
	
	[self _postNotificationName: BXEmulatorDidRemoveFileNotification
			   delegateSelector: @selector(emulatorDidRemoveFile:)
					   userInfo: userInfo];	
}


#pragma mark -
#pragma mark Filesystem validation

- (BOOL) _DOSBoxDriveInUseAtIndex: (NSUInteger)index
{
	int i;
	for (i=0; i<DOS_FILES; i++)
	{
		if (Files[i] && Files[i]->GetDrive() == index)
		{
			//DOS_File->GetDrive() returns 0 for the special CON system file,
			//which also corresponds to the drive index for A, so skip it
			if (index == 0 && !strcmp(Files[i]->GetName(), "CON")) continue;
			
			if (Files[i]->IsOpen()) return YES;
		}
	}
	return NO;
}


//If the folder was restricted, print an error to the shell and deny access
//Todo: this assumes that the check is being called from the shell; we should instead populate an NSError with the error details and let the upstream context handle it
- (BOOL) _shouldMountPath: (NSString *)thePath
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

//Todo: supplement this by getting entire OS X filepaths out of DOSBox, instead of just filenames
- (BOOL) _shouldShowFileWithName: (NSString *)fileName
{
	//Permit . and .. to be shown
	if ([fileName isEqualToString: @"."] || [fileName isEqualToString: @".."]) return YES;
	
	//Hide all hidden UNIX files
	//CHECK: will this ever hide valid DOS files?
	if ([fileName hasPrefix: @"."]) return NO;
	
	//Hide OSX and Boxer metadata files
	if ([[[self class] dosFileExclusions] containsObject: fileName]) return NO;
	return YES;
}

- (BOOL) _shouldAllowWriteAccessToPath: (NSString *)filePath onDOSBoxDrive: (DOS_Drive *)dosboxDrive
{	
	BXDrive *drive = [self _driveMatchingDOSBoxDrive: dosboxDrive];
	
	//Don't allow write access to files on drives marked as read-only
	if ([drive readOnly]) return NO;
	
	//Don't allow write access to files inside Boxer's application bundle
	filePath = [filePath stringByStandardizingPath];
	NSString *boxerPath = [[NSBundle mainBundle] bundlePath];
	if ([filePath isRootedInPath: boxerPath]) return NO;
	
	//TODO: don't allow write access to files in system directories
	
	//Let other files go through unmolested
	return YES;
}

@end
