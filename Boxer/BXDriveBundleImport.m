/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDriveBundleImport.h"
#import "BXSimpleDriveImport.h"

@interface BXDriveBundleImport ()
@property (copy, readwrite) NSString *importedDrivePath;
@end


@implementation BXDriveBundleImport
@synthesize drive = _drive;
@synthesize destinationFolder = _destinationFolder;
@synthesize importedDrivePath = _importedDrivePath;
@dynamic copyFiles, numFiles, filesTransferred, numBytes, bytesTransferred, currentPath;


+ (NSString *) nameForDrive: (BXDrive *)drive
{
	return [BXSimpleDriveImport nameForDrive: drive];
}

+ (id <BXDriveImport>) importForDrive: (BXDrive *)drive
						toDestination: (NSString *)destinationFolder
							copyFiles: (BOOL)copyFiles
{
	return 0;
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


- (void) main
{
	NSString *driveName		= [[self class] nameForDrive: [self drive]];
	NSString *destination	= [[self destinationFolder] stringByAppendingPathComponent: driveName];
	
	[self setImportedDrivePath: destination];
	
	[super main];
}
@end