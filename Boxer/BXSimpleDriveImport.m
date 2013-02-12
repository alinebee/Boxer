/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSimpleDriveImport.h"
#import "BXFileTypes.h"
#import "BXDrive.h"
#import "NSWorkspace+BXFileTypes.h"


@implementation BXSimpleDriveImport
@synthesize drive = _drive;
@synthesize destinationFolder = _destinationFolder;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
	return YES;
}

+ (BOOL) driveUnavailableDuringImport
{
    return NO;
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *importedName = nil;
	NSString *drivePath = drive.path;
	
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir, exists = [manager fileExistsAtPath: drivePath isDirectory: &isDir];
	
	if (exists)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		
		NSSet *readyTypes = [[BXFileTypes mountableFolderTypes] setByAddingObjectsFromSet: [BXFileTypes mountableImageTypes]];

		//If the drive has a letter, then place that at the start of the name.
		if (drive.letter)
        {
            importedName = drive.letter;
        }
        
		//Files and folders of the above types don't need additional renaming before import:
        //we can just use their filename directly.
		if ([workspace file: drivePath matchesTypes: readyTypes])
		{
            //TODO: strip out any leading drive letter, since the file being imported may already
            //have been named by us before.
            if (importedName.length)
                importedName = [NSString stringWithFormat: @"%@ %@", importedName, drivePath.lastPathComponent];
            else
                importedName = drivePath.lastPathComponent;
		}
		//Otherwise: if it's a directory, it will need to be renamed as a mountable folder.
		else if (isDir)
		{
            //Append the volume label to the name, if one was defined.
            if (importedName.length)
            {
                if (drive.volumeLabel.length)
                    importedName = [NSString stringWithFormat: @"%@ %@", importedName, drive.volumeLabel];
            }
            else
            {
                //Implementation note: if there's no drive letter, and no volume label,
                //we make up a volume label to avoid having an empty filename.
                if (drive.volumeLabel.length)
                    importedName = drive.volumeLabel;
                else
                    importedName = [BXDrive preferredVolumeLabelForPath: drive.path];
            }
            
			NSString *extension	= nil;
			
			//Give the mountable folder the proper file extension for its drive type
			switch (drive.type)
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
        //Otherwise: if it's a file, then it's *presumably* an ISO disc image
        //that's been given a dumb file extension (hello GOG!) and should be
        //renamed to something sensible.
        //TODO: validate that it is in fact an ISO image, once we have ISO parsing ready.
        else
        {
            NSString *baseName = drivePath.lastPathComponent.stringByDeletingPathExtension;
            NSString *fileName = [baseName stringByAppendingPathExtension: @"iso"];
            
            if (importedName.length)
                importedName = [NSString stringWithFormat: @"%@ %@", importedName, fileName];
            else
                importedName = fileName;
        }
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
		self.drive = drive;
		self.destinationFolder = destinationFolder;
		self.copyFiles = copy;
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
#pragma mark The actual operation, finally

- (BOOL) shouldPerformOperation
{
    return self.drive && self.destinationFolder;
}

- (void) performOperation
{
    self.sourcePath = self.drive.path;
    self.destinationPath = self.importedDrivePath;
    
    [super performOperation];
}

- (NSString *) importedDrivePath
{
    if (!self.drive || !self.destinationFolder) return nil;
    
	NSString *driveName			= [self.class nameForDrive: self.drive];
	NSString *destinationPath	= [self.destinationFolder stringByAppendingPathComponent: driveName];
    
    return destinationPath;
}

- (void) didPerformOperation
{
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error)
    {
        [self undoTransfer];
    }
}

@end