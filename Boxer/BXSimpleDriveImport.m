/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSimpleDriveImport.h"
#import "BXDriveBundleImport.h"
#import "BXAppController.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXDrive.h"

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

+ (Class) importClassForDrive: (BXDrive *)drive
{
	NSString *drivePath = [drive path];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	//Wrap CUE/BINs up into our custom bundle class
	NSSet *typesForBundling = [NSSet setWithObject: @"com.goldenhawk.cdrwin-cuesheet"];
	
	if ([workspace file: drivePath matchesTypes: typesForBundling]) return [BXDriveBundleImport class];
	else return [BXSimpleDriveImport class];
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
			return [drivePath lastPathComponent];
		}
		//Otherwise, it will need to be made into a mountable folder
		else if (isDir)
		{
			importedName = [drive label];
			//If the drive has a letter, then prepend it in our standard format
			if ([drive letter]) importedName = [NSString stringWithFormat: @"%@ %@", [drive letter], importedName];
			
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
	}
	return importedName;
}

#pragma mark -
#pragma mark Initialization and deallocation

+ (id <BXDriveImport>) importForDrive: (BXDrive *)drive
						toDestination: (NSString *)destinationFolder
							copyFiles: (BOOL)copyFiles
{
	return [[[self alloc] initForDrive: drive
						 toDestination: destinationFolder
							 copyFiles: copyFiles] autorelease];
}

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

- (void) main
{
	NSString *driveName		= [[self class] nameForDrive: [self drive]];
	NSString *destination	= [[self destinationFolder] stringByAppendingPathComponent: driveName];
	
	[self setSourcePath: [[self drive] path]];
	[self setDestinationPath: destination];
	
	[self setImportedDrivePath: destination];
	
	[super main];
}

- (void) undoTransfer
{
	[super undoTransfer];
}

@end