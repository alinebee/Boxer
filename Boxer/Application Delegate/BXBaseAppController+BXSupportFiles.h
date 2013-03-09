/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXApplicationModes category extends BXAppController with functions
//for managing Boxer's various Application Support files.

#import "BXBaseAppController.h"

@class BXGamebox;
@interface BXBaseAppController (BXSupportFiles)

#pragma mark -
#pragma mark Supporting directories

//Returns Boxer's default location for screenshots and other recordings.
//If createIfMissing is YES, the folder will be created if it does not exist.
//Returns nil and populates outError if createIfMissing is YES but the folder
//could not be created.
- (NSURL *) recordingsURLCreatingIfMissing: (BOOL)createIfMissing
                                     error: (out NSError **)outError;

//Returns Boxer's application support URL.
//If createIfMissing is YES, the folder will be created if it does not exist.
//Returns nil and populates outError if createIfMissing is YES but the folder
//could not be created.
- (NSURL *) supportURLCreatingIfMissing: (BOOL)createIfMissing
                                  error: (out NSError **)outError;

//Returns the path to the application support folder where Boxer should
//store state data for the specified gamebox.
//If createIfMissing is YES, the folder will be created if it does not exist.
//Returns nil and populates outError if createIfMissing is YES but the folder
//could not be created.
- (NSURL *) gameStatesURLForGamebox: (BXGamebox *)gamebox
                  creatingIfMissing: (BOOL)createIfMissing
                              error: (out NSError **)outError;

//Returns the path to the application support folder where Boxer keeps MT-32 ROM files.
//If createIfMissing is YES, the folder will be created if it does not exist.
//Returns nil and populates outError if createIfMissing is YES but the folder
//could not be created.
- (NSURL *) MT32ROMURLCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError;


#pragma mark -
#pragma mark ROM management

//Returns the path to the requested ROM file, or nil if it is not present.
- (NSURL *) MT32ControlROMURL;
- (NSURL *) MT32PCMROMURL;

//Copies the specified MT32 PCM or control ROM into the application support folder,
//making it accessible via the appropriate URL method above (depending on whether
//it was a control or PCM ROM).
//Returns the URL of the imported ROM if successful. Returns nil and populates NSError
//if the ROM could not be imported or was invalid.
- (NSURL *) importMT32ROMAtURL: (NSURL *)URL error: (out NSError **)outError;

//Validate that the ROM at the specified URL is valid and suitable for use by Boxer.
- (BOOL) validateMT32ROMAtURL: (inout NSURL **)ioValue error: (out NSError **)outError;

//When given an array of file URLs, scans them for valid ROMs and imports
//the first pair it finds. Recurses into any folders in the list.
//Returns YES if one or more ROMs were imported, or NO and populates outError
//if there was a problem (including if the URLs did not contain any MT-32 ROMs.)
- (BOOL) importMT32ROMsFromURLs: (NSArray *)URLs error: (out NSError **)outError;


@end
