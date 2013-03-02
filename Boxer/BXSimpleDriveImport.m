/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSimpleDriveImport.h"
#import "BXFileTypes.h"
#import "BXDrive.h"
#import "NSWorkspace+ADBFileTypes.h"
#import "NSFileManager+ADBUniqueFilenames.h"


@implementation BXSimpleDriveImport
@synthesize drive = _drive;
@synthesize destinationFolderURL = _destinationFolderURL;
@synthesize destinationURL = _destinationURL;


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
	
        NSString *baseName = [BXDriveImport baseNameForDrive: drive];
        NSString *extension;
        //Decide on what kind of extension to use for the file:
        //If this is one of our known image/mountable folder types then use its extension as-is
		NSSet *readyTypes = [[BXFileTypes mountableFolderTypes] setByAddingObjectsFromSet: [BXFileTypes mountableImageTypes]];
        if ([workspace file: drivePath matchesTypes: readyTypes])
        {
            extension = drivePath.pathExtension;
        }
		//Otherwise: if it's a directory, it will need to be renamed as a mountable folder.
		else if (isDir)
        {
			switch (drive.type)
			{
				case BXDriveCDROM:
					extension = [workspace preferredFilenameExtensionForType: BXCDROMFolderType];
					break;
				case BXDriveFloppyDisk:
					extension = [workspace preferredFilenameExtensionForType: BXFloppyFolderType];
					break;
				case BXDriveHardDisk:
				default:
					extension = [workspace preferredFilenameExtensionForType: BXHardDiskFolderType];
					break;
			}
        }
        //Otherwise: if it's a file, then it's *presumably* an ISO disc image that's been given
        //a file extension we don't recognise (hello GOG!) and should be renamed to something sensible.
        //TODO: validate it to determine what kind of image it really is.
        else
        {
            extension = @"iso";
        }
        
        importedName = [baseName stringByAppendingPathExtension: extension];
    }
	return importedName;
}

#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
               destinationFolderURL: (NSURL *)destinationFolderURL
						  copyFiles: (BOOL)copy;
{
	if ((self = [super init]))
	{
		self.drive = drive;
		self.destinationFolderURL = destinationFolderURL;
		self.copyFiles = copy;
	}
	return self;
}

- (void) dealloc
{
    self.drive = nil;
    self.destinationFolderURL = nil;
    self.destinationURL = nil;
    
	[super dealloc];
}


#pragma mark -
#pragma mark The actual operation, finally

- (void) main
{
    NSAssert(self.drive != nil, @"No drive provided for drive import operation.");
    NSAssert(self.destinationURL != nil || self.destinationFolderURL != nil, @"No destination provided for drive import operation.");
    
    if (!self.destinationURL)
        self.destinationURL = self.preferredDestinationURL;
    
    self.sourcePath = self.drive.path;
    self.destinationPath = self.destinationURL.path;
    
    [super main];
    
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error)
        [self undoTransfer];
}

- (NSURL *) preferredDestinationURL
{
    if (!self.drive || !self.destinationFolderURL) return nil;
    
	NSString *driveName			= [self.class nameForDrive: self.drive];
    NSURL *destinationURL       = [self.destinationFolderURL URLByAppendingPathComponent: driveName];
    
    //Check that there isn't already a file with the same name at the location.
    //If there is, auto-increment the name until we land on one that's unique.
    NSURL *uniqueDestinationURL = [[NSFileManager defaultManager] uniqueURLForURL: destinationURL
                                                                   filenameFormat: BXUniqueDriveNameFormat];
    
    return uniqueDestinationURL;
}

@end