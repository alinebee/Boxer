/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController+BXSupportFiles.h"
#import "ADBPathEnumerator.h"
#import "RegexKitLite.h"
#import "BXEmulatedMT32.h"
#import "NSError+ADBErrorHelpers.h"
#import "BXGamebox.h"

//Files matching these patterns will be assumed to be of the respective ROM type.
NSString * const MT32ControlROMFilenamePattern = @"control";
NSString * const MT32PCMROMFilenamePattern = @"pcm";


@interface BXBaseAppController (BXSupportFilesInternal)

- (NSURL *) _URLForMT32ROMMatchingPattern: (NSString *)pattern;

@end


@implementation BXBaseAppController (BXSupportFiles)

- (NSString *) statesPathForGamebox: (BXGamebox *)gamebox
                  creatingIfMissing: (BOOL) createIfMissing
{
    if (gamebox == nil)
        return nil;
    
	NSString *supportPath = [self supportPathCreatingIfMissing: NO];
    NSString *statesPath = [supportPath stringByAppendingPathComponent: @"Gamebox States"];
    
    NSString *identifier = gamebox.gameIdentifier;
    
    //If the package lacks an identifier, we cannot assign it a path for state storage.
    if (!identifier)
        return nil;
    
    NSString *gameboxStatesPath = [statesPath stringByAppendingPathComponent: identifier];
    if (createIfMissing)
    {
		[[NSFileManager defaultManager] createDirectoryAtPath: gameboxStatesPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
    }
    
    return gameboxStatesPath;
}

- (NSURL *) recordingsURLCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError
{
    return [[NSFileManager defaultManager] URLForDirectory: NSDesktopDirectory
                                                  inDomain: NSUserDomainMask
                                         appropriateForURL: nil
                                                    create: createIfMissing
                                                     error: outError];
}

- (NSURL *) supportURLCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *baseURL = [[manager URLsForDirectory: NSApplicationSupportDirectory inDomains: NSUserDomainMask] objectAtIndex: 0];
    NSURL *supportURL = [baseURL URLByAppendingPathComponent: @"Boxer"];
    
    if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtURL: supportURL
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: outError];
	}
    return supportURL;
}

- (NSString *) recordingsPathCreatingIfMissing: (BOOL)createIfMissing
{
    return [self recordingsURLCreatingIfMissing: createIfMissing error: NULL].path;
}

- (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing
{
    return [self supportURLCreatingIfMissing: createIfMissing error: NULL].path;
}

- (NSURL *) MT32ROMURLCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError
{
    NSURL *supportURL   = [self supportURLCreatingIfMissing: NO error: NULL];
    NSURL *ROMsURL      = [supportURL URLByAppendingPathComponent: @"MT-32 ROMs"];
    
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtURL: ROMsURL
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: outError];
	}
	return ROMsURL;
}


//The user may have put the ROM files into the folder themselves,
//so we can't rely on them having a consistent naming scheme.
//Instead, return the first file that matches a flexible filename pattern.
- (NSURL *) _URLForMT32ROMMatchingPattern: (NSString *)pattern
{
    NSURL *ROMURL = [self MT32ROMURLCreatingIfMissing: NO error: NULL];
    
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: ROMURL
                                                             includingPropertiesForKeys: nil
                                                                                options: options
                                                                           errorHandler: NULL];
    
    for (NSURL *URL in enumerator)
    {
        NSString *fileName = URL.lastPathComponent;
        if ([fileName isMatchedByRegex: pattern
                               options: RKLCaseless
                               inRange: NSMakeRange(0, fileName.length)
                                 error: nil])
        {
            return URL;
        }
    }
    return nil;
}

- (NSURL *) MT32ControlROMURL
{
    return [self _URLForMT32ROMMatchingPattern: MT32ControlROMFilenamePattern];
}

- (NSURL *) MT32PCMROMURL
{
    return [self _URLForMT32ROMMatchingPattern: MT32PCMROMFilenamePattern];
}

- (NSURL *) _importMT32ROMFromURL: (NSURL *)sourceURL
                           toName: (NSString *)fileName
                            error: (NSError **)outError
{
    NSURL *baseURL = [self MT32ROMURLCreatingIfMissing: YES error: outError];
    if (!baseURL)
        return nil;
    
    NSURL *destinationURL = [baseURL URLByAppendingPathComponent: fileName];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    
    //Trash any existing ROM at the destination URL. (We ignore any errors from this since
    //if the trashing failed, the copy will fail too with a file-already-exists error.)
    [manager trashItemAtURL: destinationURL resultingItemURL: NULL error: NULL];
    
    BOOL succeeded = [manager copyItemAtURL: sourceURL
                                      toURL: destinationURL
                                      error: outError];
    
    if (succeeded)
        return destinationURL;
    else
        return nil;
}

- (NSURL *) importMT32ROMAtURL: (NSURL *)URL error: (out NSError **)outError
{
    BXMT32ROMType type = [BXEmulatedMT32 typeOfROMAtURL: URL error: outError];
    
    if (type != BXMT32ROMTypeUnknown)
    {
        BOOL isControl = (type & BXMT32ROMIsControl) == BXMT32ROMIsControl;
        NSURL *importedURL;
        if (isControl)
        {
            [self willChangeValueForKey: @"MT32ControlROMURL"];
            importedURL = [self _importMT32ROMFromURL: URL toName: @"Control.rom" error: outError];
            [self didChangeValueForKey: @"MT32ControlROMURL"];
        }
        else
        {
            [self willChangeValueForKey: @"MT32PCMROMURL"];
            importedURL = [self _importMT32ROMFromURL: URL toName: @"PCM.rom" error: outError];
            [self didChangeValueForKey: @"MT32PCMROMURL"];
        }
        return importedURL;
    }
    else return nil;
}

- (BOOL) validateMT32ROMAtURL: (inout NSURL **)ioValue error: (out NSError **)outError
{
    NSURL *URL = *ioValue;
    return ([BXEmulatedMT32 typeOfROMAtURL: URL error: outError] != BXMT32ROMTypeUnknown);
}

- (BOOL) importMT32ROMsFromURLs: (NSArray *)URLs error: (NSError **)outError
{
#define NUM_ROM_TYPES 4
    NSMutableDictionary *ROMs = [NSMutableDictionary dictionaryWithCapacity: NUM_ROM_TYPES];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    //Go through all the files the user has chosen, checking for matching ROMs.
    for (NSURL *URL in URLs)
    {
        //Nonexistent files should never find their way in here, but just in case...
        if (![URL checkResourceIsReachableAndReturnError: outError])
            return NO;
        
        NSNumber *isDirFlag = nil;
        BOOL checkedDir = [URL getResourceValue: &isDirFlag forKey: NSURLIsDirectoryKey error: outError];
        if (!checkedDir)
            return NO;
        
        BOOL isDir = isDirFlag.boolValue;
        BXMT32ROMType type;
        
        if (isDir)
        {
            NSLog(@"Scanning directory at %@ for subfiles", URL);
            NSDirectoryEnumerator *enumerator = [manager enumeratorAtURL: URL
                                              includingPropertiesForKeys: @[NSURLIsDirectoryKey]
                                                                 options: NSDirectoryEnumerationSkipsHiddenFiles
                                                            errorHandler: NULL];
            
            for (NSURL *subURL in enumerator)
            {
                NSLog(@"Scanning file at %@ for ROMness", subURL);
                isDirFlag = nil;
                checkedDir = [subURL getResourceValue: &isDirFlag forKey: NSURLIsDirectoryKey error: NULL];
                //Skip directories
                if (!checkedDir || isDirFlag.boolValue)
                    continue;
                
                type = [BXEmulatedMT32 typeOfROMAtURL: subURL error: NULL];
                if (type != BXMT32ROMTypeUnknown)
                {
                    [ROMs setObject: subURL forKey: @(type)];
                    //If we've now found all the ROMs we'll ever need, then stop looking.
                    if (ROMs.count >= NUM_ROM_TYPES) break;
                }
            }
        }
        else
        {
            NSLog(@"Scanning file at %@ for ROMness", URL);
            type = [BXEmulatedMT32 typeOfROMAtURL: URL error: NULL];
            if (type != BXMT32ROMTypeUnknown)
            {
                [ROMs setObject: URL forKey: @(type)];
                //If we've now found all the ROMs we'll ever need, then stop looking.
                if (ROMs.count >= NUM_ROM_TYPES) break;
            }
        }
    }
    
    if (ROMs.count)
    {
        //Now, let's see what we found in the hunt: look for a pair of CM-32L ROMs or a pair of MT-32 ROMs.
        NSURL *controlROM   = [ROMs objectForKey: @(BXCM32LControl)];
        NSURL *PCMROM       = [ROMs objectForKey: @(BXCM32LPCM)];
        
        if (!controlROM || !PCMROM)
        {
            controlROM = [ROMs objectForKey: @(BXMT32Control)];
            PCMROM = [ROMs objectForKey: @(BXMT32PCM)];
        }
        
        //If we have a match for both control ROM and PCM ROM, import them together to replace any existing ROM(s).
        if (controlROM && PCMROM)
        {
            BOOL importedControl = [self importMT32ROMAtURL: controlROM error: outError] != nil;
            if (!importedControl)
                return NO;
            
            BOOL importedPCM = [self importMT32ROMAtURL: PCMROM error: outError] != nil;
            if (!importedPCM)
                return NO;
            
            return YES;
        }
        
        //If we couldn't find a pair of matching ROMs, then try and match one of the ROMs
        //we found against one of our previously-imported ROMs.
        else
        {
            NSURL *existingROMs[2] = { [self MT32ControlROMURL], [self MT32PCMROMURL] };
            for (NSUInteger i=0; i<2; i++)
            {
                NSURL *existingROM = existingROMs[i];
                if (!existingROM)
                    continue;
                
                BXMT32ROMType existingType = [BXEmulatedMT32 typeOfROMAtURL: existingROM error: NULL];
                BXMT32ROMType matchingType = (existingType & BXMT32ROMIsControl) ? BXMT32ROMIsPCM : BXMT32ROMIsControl;
                matchingType |= (existingType & BXMT32ModelMask);
                
                //If we found a suitable match for one of our existing ROMs, import it now.
                NSURL *matchingROMURL = [ROMs objectForKey: @(matchingType)];
                if (matchingROMURL)
                {
                    return ([self importMT32ROMAtURL: matchingROMURL error: outError] != nil);
                }
                else
                {
                    BXMT32ROMType mismatchingType = matchingType;
                    if (mismatchingType & BXMT32ROMIsCM32L)
                        mismatchingType = (mismatchingType & ~BXMT32ROMIsCM32L) | BXMT32ROMIsMT32;
                    else
                        mismatchingType = (mismatchingType & ~BXMT32ROMIsMT32) | BXMT32ROMIsCM32L;
                    
                    NSURL *mismatchedROM = [ROMs objectForKey: @(mismatchingType)];
                    
                    //If we couldn't find a matching ROM, but we did find other ROMs that don't match the same model,
                    //then flag this as a mismatch error.
                    if (mismatchedROM != nil)
                    {
                        if (outError)
                        {
                            BOOL isControlROM = (matchingType & BXMT32ROMIsControl) == BXMT32ROMIsControl;
                            NSString *controlROMDescription = NSLocalizedString(@"control ROM", @"The term to use for MT-32 control ROMs in error messages.");
                            NSString *PCMROMDescription = NSLocalizedString(@"PCM ROM", @"The term to use for MT-32 PCM ROMs in error messages.");
                            
                            NSString *titleFormat = NSLocalizedString(@"“%1$@” is from a different MT-32 model than the existing %2$@.",
                                                                      @"Bold error message shown when user attempts to add a PCM ROM that doesn't match an already-imported control ROM or vice-versa. %1$@ is the filename of the new ROM, and %2$@ is the proper term for that kind of ROM (control or PCM).");
                            
                            NSString *suggestionFormat = NSLocalizedString(@"You will need to a find a matching %1$@, or else replace both ROMs with ones from the same model.",
                                                                           @"Explanatory text shown when user attempts to add a PCM ROM that doesn’t match an already-imported control ROM, or vice-versa. %1$@ is the proper term for that kind of ROM.");
                            
                            NSString *displayName;
                            BOOL gotDisplayName = [mismatchedROM getResourceValue: &displayName forKey: NSURLLocalizedNameKey error: NULL];
                            if (!gotDisplayName)
                                displayName = mismatchedROM.lastPathComponent;
                            
                            NSString *title = [NSString stringWithFormat: titleFormat, displayName, (isControlROM ? PCMROMDescription : controlROMDescription)];
                            NSString *suggestion = [NSString stringWithFormat: suggestionFormat, (isControlROM ? controlROMDescription : PCMROMDescription)];
                            
                            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                            code: BXEmulatedMT32MismatchedROMs
                                                        userInfo: @{NSLocalizedDescriptionKey: title, NSLocalizedRecoverySuggestionErrorKey: suggestion} ];
                        }
                        return NO;
                    }
                }
            }
            
            //If we got this far, then we found ROMs but didn't match any of them against a suitable pre-existing ROM.
            //In this case, just import the first ROM we can use, replacing any existing ROM in the same slot.
            
            //In case we found multiple ROMs of the same type, import the highest one: this will prefer CM-32L ROMs over MT-32 ROMs.
            NSArray *sortedKeys = [ROMs.allKeys sortedArrayUsingSelector: @selector(compare:)];
            NSURL *ROMToImport = [ROMs objectForKey: sortedKeys.lastObject];
            
            if (ROMToImport)
            {
                return ([self importMT32ROMAtURL: ROMToImport error: outError] != nil);
            }
        }
    }
    
    //If we got this far, we didn't find any ROMs to import at all.
    if (outError)
    {
        NSString *explanation = NSLocalizedString(@"A control ROM and PCM ROM are needed to emulate the MT-32. These files are normally named “MT32_CONTROL.ROM” and “MT32_PCM.ROM”.",
                                                  @"Explanatory text shown when Boxer could not find any valid MT-32 ROMs to import.");
        
        NSString *title;
        //Decide how to phrase the error message based on what file(s) the user dragged in.
        if (URLs.count == 1)
        {
            NSURL *URL = [URLs objectAtIndex: 0];
            NSDictionary *attribs = [URL resourceValuesForKeys: @[NSURLIsDirectoryKey, NSURLLocalizedNameKey] error: NULL];
            
            BOOL isDir = [[attribs objectForKey: NSURLIsDirectoryKey] boolValue];
            NSString *displayName = [attribs objectForKey: NSURLLocalizedNameKey];
            if (!displayName)
                displayName = URL.lastPathComponent;
            
            NSString *titleFormat;
            
            //A single folder was chosen, from whose contents we couldn't find any suitable ROMs.
            if (isDir)
            {
                titleFormat = NSLocalizedString(@"“%1$@” does not contain any suitable MT-32 ROMs.",
                                                @"Error message shown when Boxer could not find any valid MT-32 ROMs to import from the folder the user chose. %1$@ is the filename of the folder.");
            }
            //A single file was chosen that wasn't a valid ROM of either type.
            else
            {
                titleFormat = NSLocalizedString(@"“%1$@” is not a valid MT-32 ROM.",
                                                @"Error message shown when the file the user selected was not a valid MT-32 ROM. %1$@ is the filename of the file.");
                
                //Don't show the explanation for a single file,
                //since clearly the user knows what they're about.
                explanation = @"";
            }
            
            title = [NSString stringWithFormat: titleFormat, displayName];
        }
        //Multiple files were chosen, from which we couldn't find any suitable ROMs.
        else
        {
            title = NSLocalizedString(@"No suitable MT-32 ROMs were found.",
                                      @"Main error text shown when Boxer could not find any valid MT-32 ROMs to import out of a set of several files.");
        }
        
        *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                        code: BXEmulatedMT32MissingROM
                                    userInfo: @{
                   NSLocalizedDescriptionKey: title,
       NSLocalizedRecoverySuggestionErrorKey: explanation
                     }];
    }
    return NO;
}

@end
