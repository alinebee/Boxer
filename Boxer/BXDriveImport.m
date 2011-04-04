/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDriveImport.h"
#import "BXISOImport.h"
#import "BXDriveBundleImport.h"
#import "BXSimpleDriveImport.h"

@implementation BXDriveImport: BXOperation

+ (Class) importClassForDrive: (BXDrive *)drive
{
	NSArray *importClasses = [NSArray arrayWithObjects:
							  [BXISOImport class],
							  [BXDriveBundleImport class],
							  [BXSimpleDriveImport class],
							  nil];
	
	for (Class importClass in importClasses)
		if ([importClass isSuitableForDrive: drive]) return importClass;
	
	//If we got this far, no appropriate class could be found
	return nil;
}

+ (id <BXDriveImport>) importForDrive: (BXDrive *)drive
						toDestination: (NSString *)destinationFolder
							copyFiles: (BOOL)copyFiles
{
	Class importClass = [self importClassForDrive: drive];
	if (importClass)
	{
		return [[[importClass alloc] initForDrive: drive
									toDestination: destinationFolder
										copyFiles: copyFiles] autorelease];
	}
	else return nil;
}

@end