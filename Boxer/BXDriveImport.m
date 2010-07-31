/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveImport.h"
#import "BXAppController.h"
#import "BXDrive.h"
#import "NSWorkspace+BXFileTypes.h"


@implementation BXDriveImport

#pragma mark -
#pragma mark Helper class methods

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
#pragma mark Initializers

+ (id) importForDrive: (BXDrive *)drive toFolder: (NSString *)destination copyFiles: (BOOL)copy
{
	return [[[self alloc] initForDrive: drive toFolder: destination copyFiles: copy] autorelease];
}

- (id) initForDrive: (BXDrive *)drive toFolder: (NSString *)destination copyFiles: (BOOL)copy
{
	NSString *source = [drive path];
	NSString *fullDestination = [destination stringByAppendingPathComponent: [[self class] nameForDrive: drive]];
	
	if ((self = [super initFromPath: source toPath: fullDestination copyFiles: copy]))
	{
		[self setContextInfo: drive];
	}
	return self;
}

@end