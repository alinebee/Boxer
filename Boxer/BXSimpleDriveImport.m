/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSimpleDriveImport.h"
#import "BXAppController.h"
#import "BXDrive.h"
#import "NSWorkspace+BXFileTypes.h"


@interface BXSimpleDriveImport ()
@property (copy, readwrite) NSString *importedDrivePath;
@end

@implementation BXSimpleDriveImport
@synthesize drive = _drive;
@synthesize destinationFolder = _destinationFolder;
@synthesize importedDrivePath = _importedDrivePath;
@dynamic copyFiles, numFiles, filesTransferred, numBytes, bytesTransferred, currentPath;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
	return YES;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *importedName = nil;
	NSString *drivePath = [drive path];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir, exists = [manager fileExistsAtPath: drivePath isDirectory: &isDir];
	
	if (exists)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		
		NSSet *readyTypes = [[BXAppController mountableFolderTypes] setByAddingObjectsFromSet: [BXAppController mountableImageTypes]];
		
		//Folders of the above types don't need additional work to import: we can just use their filename directly
		if ([workspace file: drivePath matchesTypes: readyTypes])
		{
			importedName = [drivePath lastPathComponent];
		}
		//Otherwise, it will need to be made into a mountable folder
		else if (isDir)
		{
			importedName = [drive volumeLabel];
			
			NSString *extension	= nil;
			
			//Give the mountable folder the proper file extension for its drive type
			switch ([drive type])
			{
				case BXDriveCDROM:
					extension = @"cdrom";
					break;
				case BXDriveFloppyDisk:
					extension = @"floppy";
					break;
				case BXDriveHardDisk:
				default:
					extension = @"harddisk";
					break;
			}
			importedName = [importedName stringByAppendingPathExtension: extension];
		}
		
		//If the drive has a letter, then prepend it in our standard format
		if ([drive letter]) importedName = [NSString stringWithFormat: @"%@ %@", [drive letter], importedName];
	}
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
		[self setCopyFiles: copy];
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
#pragma mark The actual operation, finally

- (void) setDrive: (BXDrive *)newDrive
{
    if (![_drive isEqual: newDrive])
    {
        [_drive release];
        _drive = [newDrive retain];
        
        [self setSourcePath: [newDrive path]];
    }
}

//Automatically populate the destination path the first time we need it,
//based on the drive and destination folder.
- (NSString *) destinationPath
{
    if (![super destinationPath] && [self drive] && [self destinationFolder])
    {
        NSString *driveName		= [[self class] nameForDrive: [self drive]];
        NSString *destination	= [[self destinationFolder] stringByAppendingPathComponent: driveName];
        
        [self setDestinationPath: destination];
    }
    return [super destinationPath];
}

- (void) didPerformOperation
{
    //Populate the imported drive path once we're done, assuming nothing went wrong.
    if (![self error])
    {
        [self setImportedDrivePath: [self destinationPath]];
    }
}

- (BOOL) succeeded
{
    return [super succeeded] && [self importedDrivePath];
}

- (BOOL) undoTransfer
{
	return [super undoTransfer];
}

@end