/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDriveImport.h"
#import "BXCDImageImport.h"
#import "BXBinCueImageImport.h"
#import "BXDriveBundleImport.h"
#import "BXSimpleDriveImport.h"


NSString * const BXUniqueDriveNameFormat = @"%1$@ (%3$lu).%2$@";

@implementation BXDriveImport: ADBOperation

+ (Class) importClassForDrive: (BXDrive *)drive
{
	NSArray *importClasses = @[
        [BXBinCueImageImport class],
        [BXCDImageImport class],
        [BXDriveBundleImport class],
        [BXSimpleDriveImport class],
    ];
	
	for (Class importClass in importClasses)
		if ([importClass isSuitableForDrive: drive]) return importClass;
	
	//If we got this far, no appropriate class could be found
	return nil;
}

+ (id <BXDriveImport>) importOperationForDrive: (BXDrive *)drive
                          destinationFolderURL: (NSURL *)destinationFolderURL
                                     copyFiles: (BOOL)copyFiles
{
	Class importClass = [self importClassForDrive: drive];
	if (importClass)
	{
        NSAssert1([importClass conformsToProtocol: @protocol(BXDriveImport)], @"Non-conforming drive import class provided: %@", importClass);
        
		return [[(id <BXDriveImport>)[importClass alloc] initForDrive: drive
                                                 destinationFolderURL: destinationFolderURL
                                                            copyFiles: copyFiles] autorelease];
	}
	else return nil;
}

+ (id <BXDriveImport>) fallbackForFailedImport: (id <BXDriveImport>)failedImport
{
	Class fallbackClass = nil;
	
	//Use a simple file copy to replace a failed disc-image rip
	if ([failedImport isKindOfClass: [BXCDImageImport class]])
	{
		fallbackClass = [BXSimpleDriveImport class];
	}
	
	if (fallbackClass)
	{
		//Create a new import operation with the same parameters as the old one
		return [[[fallbackClass alloc] initForDrive: failedImport.drive
                               destinationFolderURL: failedImport.destinationFolderURL
										  copyFiles: failedImport.copyFiles] autorelease];
	}
	//No fallback could be found
	return nil;
}
@end
