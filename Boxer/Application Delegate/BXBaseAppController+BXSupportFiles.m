/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController+BXSupportFiles.h"
#import "BXPathEnumerator.h"
#import "RegexKitLite.h"
#import "BXEmulatedMT32.h"
#import "BXPathEnumerator.h"
#import "BXGamebox.h"

//Files matching these patterns will be assumed to be of the respective ROM type.
NSString * const MT32ControlROMFilenamePattern = @"control";
NSString * const MT32PCMROMFilenamePattern = @"pcm";


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

- (NSString *) recordingsPathCreatingIfMissing: (BOOL)createIfMissing
{
    NSString *desktopPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
    return desktopPath;
}

- (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSString *supportPath = [basePath stringByAppendingPathComponent: @"Boxer"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: supportPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return supportPath;
}

- (NSString *) MT32ROMPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *supportPath   = [self supportPathCreatingIfMissing: NO];
    NSString *ROMPath       = [supportPath stringByAppendingPathComponent: @"MT-32 ROMs"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: ROMPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return ROMPath;
}


//The user may have put the ROM files into the folder themselves,
//so we can't rely on them having a consistent naming scheme.
//Instead, return the first file that matches a flexible filename pattern.
- (NSString *) _pathToMT32ROMMatchingPattern: (NSString *)pattern
{
    NSString *ROMPath = [self MT32ROMPathCreatingIfMissing: NO];
    
    BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: ROMPath];
    [enumerator setSkipSubdirectories: YES];
    [enumerator setSkipHiddenFiles: YES];
    [enumerator setSkipPackageContents: YES];
    for (NSString *filePath in enumerator)
    {
        NSString *fileName = [filePath lastPathComponent];
        if ([fileName isMatchedByRegex: pattern
                               options: RKLCaseless
                               inRange: NSMakeRange(0, [fileName length])
                                 error: nil])
        {
            return filePath;
        }
    }
    return nil;
}

- (NSString *) pathToMT32ControlROM
{
    return [self _pathToMT32ROMMatchingPattern: MT32ControlROMFilenamePattern];
}

- (NSString *) pathToMT32PCMROM
{
    return [self _pathToMT32ROMMatchingPattern: MT32PCMROMFilenamePattern];
}

- (BOOL) _importMT32ROMFromPath: (NSString *)sourcePath
                         toName: (NSString *)fileName
                          error: (NSError **)outError
{
    NSString *basePath = [self MT32ROMPathCreatingIfMissing: YES];
    NSString *destinationPath = [basePath stringByAppendingPathComponent: fileName];
    
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    
    //Trash any previous ROM when replacing.
    [workspace performFileOperation: NSWorkspaceRecycleOperation
                             source: basePath
                        destination: @""
                              files: [NSArray arrayWithObject: fileName]
                                tag: NULL];
    
    BOOL succeeded = [manager copyItemAtPath: sourcePath
                                      toPath: destinationPath
                                       error: outError];
    
    [manager release];
    return succeeded;
}

- (BOOL) importMT32ControlROM: (NSString *)ROMPath
                        error: (NSError **)outError
{
    BOOL isValid = [self validateMT32ControlROM: &ROMPath error: outError];
    if (isValid)
    {
        [self willChangeValueForKey: @"pathToMT32ControlROM"];
        BOOL succeeded = [self _importMT32ROMFromPath: ROMPath toName: @"Control.rom" error: outError];
        [self didChangeValueForKey: @"pathToMT32ControlROM"];
        return succeeded;
    }
    else return NO;
}

- (BOOL) importMT32PCMROM: (NSString *)ROMPath
                    error: (NSError **)outError
{
    BOOL isValid = [self validateMT32PCMROM: &ROMPath error: outError];
    if (isValid)
    {
        [self willChangeValueForKey: @"pathToMT32PCMROM"];
        BOOL succeeded =  [self _importMT32ROMFromPath: ROMPath toName: @"PCM.rom" error: outError];
        [self didChangeValueForKey: @"pathToMT32PCMROM"];
        return succeeded;
    }
    else return NO;
}


- (BOOL) _isValidMT32ROMAtPath: (NSString *)path type: (BXMT32ROMType *)type isControlROM: (BOOL *)isControlROM
{
    if (type) *type = BXMT32ROMTypeUnknown;
    if (isControlROM) *isControlROM = NO;
    
    NSString *fileName = [[path lastPathComponent] lowercaseString];
    
    if (![[fileName pathExtension] isEqualToString: @"rom"]) return NO;
    
    if ([fileName isMatchedByRegex: MT32ControlROMFilenamePattern])
    {
        BXMT32ROMType detectedType = [BXEmulatedMT32 typeOfControlROMAtPath: path error: nil];
        if (detectedType != BXMT32ROMTypeUnknown)
        {
            if (isControlROM) *isControlROM = YES;
            if (type) *type = detectedType;
            return YES;
        }
    }
    else if ([fileName isMatchedByRegex: MT32PCMROMFilenamePattern])
    {
        BXMT32ROMType detectedType = [BXEmulatedMT32 typeOfPCMROMAtPath: path error: nil];
        if (detectedType != BXMT32ROMTypeUnknown)
        {
            if (isControlROM) *isControlROM = NO;
            if (type) *type = detectedType;
            return YES;
        }
    }
    return NO;
}

- (BOOL) importMT32ROMsFromPaths: (NSArray *)paths error: (NSError **)outError
{
#define NUM_ROM_TYPES 2
    
    //We store the ROMs we've discovered here, indexed by ROM type.
    //This lets us pair up ROMs easily once we're done.
    NSMutableDictionary *controlROMs    = [NSMutableDictionary dictionaryWithCapacity: NUM_ROM_TYPES];
    NSMutableDictionary *PCMROMs        = [NSMutableDictionary dictionaryWithCapacity: NUM_ROM_TYPES];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    
    //Go through all the files the user has chosen, checking for matching ROMs.
    for (NSString *path in paths)
    {
        BOOL isDir, exists = [manager fileExistsAtPath: path isDirectory: &isDir];
        
        //Nonexistsent files should never find their way in here, but just in case...
        if (!exists) continue;
        
        BOOL isControlROM;
        BXMT32ROMType type;
        
        //FIXME: this logic is duplicated below, inside the directory enumeration.
        //Try to merge the two somehow.
        if (!isDir && [self _isValidMT32ROMAtPath: path type: &type isControlROM: &isControlROM])
        {
            NSNumber *key = [NSNumber numberWithInteger: type];
            NSMutableDictionary *dict = isControlROM ? controlROMs : PCMROMs;
            if (![dict objectForKey: key]) [dict setObject: path forKey: key];
        }
        else if (isDir)
        {
            //Enumerate any directories to check all the files within those paths.
            BXPathEnumerator *enumerator = [BXPathEnumerator enumeratorAtPath: path];
            [enumerator setSkipHiddenFiles: YES];
            [enumerator setSkipPackageContents: YES];
        
            for (NSString *subpath in enumerator)
            {
                //Don't bother checking folders for ROMness
                if (![[[enumerator fileAttributes] fileType] isEqualToString: NSFileTypeRegular]) continue;
                
                if ([self _isValidMT32ROMAtPath: subpath type: &type isControlROM: &isControlROM])
                {
                    NSNumber *key = [NSNumber numberWithInteger: type];
                    NSMutableDictionary *dict = isControlROM ? controlROMs : PCMROMs;
                    if (![dict objectForKey: key]) [dict setObject: subpath forKey: key];
                }
                
                //If we've now found all the ROMs we'll ever need, then stop looking.
                if ([controlROMs count] == NUM_ROM_TYPES && [PCMROMs count] == NUM_ROM_TYPES) break;
            }
        }
        if ([controlROMs count] == NUM_ROM_TYPES && [PCMROMs count] == NUM_ROM_TYPES) break;
    }
    
    //Now, let's see what we found in the hunt.
    NSString *controlROM = nil;
    NSString *PCMROM = nil;
    
    //Match a control ROM up with a compatible PCM ROM if we can.
    //Sort the keys so that we pick out CM-32L ROMs in preference to MT-32 ones.
    //(Our type constant for the CM-32L is higher than our one for the MT-32.)
    NSArray *sortedKeys = [[controlROMs allKeys] sortedArrayUsingSelector: @selector(compare:)];
    for (NSNumber *key in [sortedKeys reverseObjectEnumerator])
    {
        if ([PCMROMs objectForKey: key])
        {
            controlROM = [controlROMs objectForKey: key];
            PCMROM     = [PCMROMs objectForKey: key];
            break;
        }
    }
    
    //If we couldn't find a pair of matching ROMs, then try and find a single ROM
    //(and only one) to match against our existing ROMs.
    if (!controlROM && !PCMROM)
    {
        NSString *currentControlROM = [self pathToMT32ControlROM];
        NSString *currentPCMROM     = [self pathToMT32PCMROM];
        //Determine what type of ROMs we already have installed, if any
        BXMT32ROMType currentControlROMType = [BXEmulatedMT32 typeOfControlROMAtPath: currentControlROM
                                                                               error: nil];
        BXMT32ROMType currentPCMROMType     = [BXEmulatedMT32 typeOfPCMROMAtPath: currentPCMROM
                                                                           error: nil];
        
        //If we have a valid control ROM already, then try to pick out a matching PCM ROM.
        if (currentControlROMType)
        {
            PCMROM = [PCMROMs objectForKey: [NSNumber numberWithInteger: currentControlROMType]];
            
            //If we couldn't find a match, but we did find other ROMs that don't match,
            //then flag this as a mismatch error
            if (!PCMROM && [PCMROMs count])
            {
                if (outError)
                {
                    NSString *conflictingROM = [[PCMROMs allValues] lastObject];
                    NSString *titleFormat = NSLocalizedString(@"“%1$@” is from a different MT-32 model than the existing control ROM.",
                                                              @"Error message shown when user attempts to add a PCM ROM that doesn't match an already-imported control ROM. %1$@ is the filename of the new ROM.");
                    
                    NSString *description = NSLocalizedString(@"You will need to a find a matching PCM ROM, or else replace both ROMs with ones from the same model.",
                                                              @"Explanatory text shown when user attempts to add a PCM ROM that doesn’t match an already-imported control ROM.");
                    
                    NSString *title = [NSString stringWithFormat: titleFormat, [manager displayNameAtPath: conflictingROM]];
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              title, NSLocalizedDescriptionKey,
                                              description, NSLocalizedRecoverySuggestionErrorKey,
                                              nil];
                    
                    *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                    code: BXEmulatedMT32MismatchedROMs
                                                userInfo: userInfo];
                }
                return NO;
            }
            //If no PCM ROMs were given, check if we're being given a new control ROM 
            //to replace our existing one.
            else if (![PCMROMs count] && [controlROMs count])
            {
                controlROM = [[controlROMs allValues] lastObject];
            }
        }
        
        //If we have a valid PCM ROM and didn't just find another ROM to replace it,
        //then try to pick out a matching control ROM for it
        if (currentPCMROMType && !PCMROM)
        {
            controlROM = [controlROMs objectForKey: [NSNumber numberWithInteger: currentPCMROMType]];
            if (!controlROM && [controlROMs count])
            {
                if (outError)
                {
                    NSString *conflictingROM = [[controlROMs allValues] lastObject];
                    NSString *titleFormat = NSLocalizedString(@"“%1$@” is from a different MT-32 model than the existing PCM ROM.",
                                                              @"Error message shown when user attempts to add a control ROM that doesn't match an already-imported PCM ROM. %1$@ is the filename of the new ROM.");
                    
                    NSString *description = NSLocalizedString(@"You will need to a find a matching control ROM, or else replace both ROMs with ones from the same model.",
                                                              @"Explanatory text shown when user attempts to add a control ROM that doesn’t match an already-imported PCM ROM.");
                    
                    NSString *title = [NSString stringWithFormat: titleFormat, [manager displayNameAtPath: conflictingROM]];
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              title, NSLocalizedDescriptionKey,
                                              description, NSLocalizedRecoverySuggestionErrorKey,
                                              nil];
                    
                    *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                    code: BXEmulatedMT32MismatchedROMs
                                                userInfo: userInfo];
                }
                return NO;
            }
            //If no control ROMs were given, check if we're being given a new PCM ROM 
            //to replace our existing one.
            else if (![controlROMs count] && [PCMROMs count])
            {
                PCMROM = [[PCMROMs allValues] lastObject];
            }
        }
        
        //If we don't have *any* ROMs yet, then just pick any control ROM or PCM ROM to import
        //(But not both, since if we got this far then any pairs we found were mismatched.)
        if (!currentControlROMType && !currentPCMROMType)
        {
            controlROM = [[controlROMs allValues] lastObject];
            if (!controlROM)
                PCMROM = [[PCMROMs allValues] lastObject];
        }
    }
    
    //If we found a control ROM or a PCM ROM or both, import them now.
    if (controlROM)
    {
        BOOL succeeded = [self importMT32ControlROM: controlROM error: outError];
        //If the import failed for some reason, bail out before we do any more damage.
        if (!succeeded) return NO;
    }
    if (PCMROM)
    {
        BOOL succeeded = [self importMT32PCMROM: PCMROM error: outError];
        if (!succeeded) return NO;
    }
    
    //Hooray! We imported something today.
    if (controlROM || PCMROM) return YES;
    
    
    //If we got this far, we couldn't find any ROMs to import.
    if (outError)
    {
        NSString *explanation = NSLocalizedString(@"A control ROM and PCM ROM are needed to emulate the MT-32. These files are normally named “MT32_CONTROL.ROM” and “MT32_PCM.ROM”.",
                                                  @"Explanatory text shown when Boxer could not find any valid MT-32 ROMs to import.");
        
        NSString *title;
        //Decide how to phrase the error message based on what file(s) the user dragged in.
        if ([paths count] == 1)
        {
            NSString *path = [paths objectAtIndex: 0];
            BOOL isFolder = NO;
            [manager fileExistsAtPath: path isDirectory: &isFolder];
            
            NSString *titleFormat;
            //A single folder was chosen, from whose contents we couldn't find any suitable ROMs.
            if (isFolder)
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
            NSString *displayName = [manager displayNameAtPath: path];
            title = [NSString stringWithFormat: titleFormat, displayName];
        }
        //Multiple files were chosen, from which we couldn't find any suitable ROMs.
        else
        {
            title = NSLocalizedString(@"No suitable MT-32 ROMs were found.",
                                      @"Main error text shown when Boxer could not find any valid MT-32 ROMs to import out of a set of several files.");
        }
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  title, NSLocalizedDescriptionKey,
                                  explanation, NSLocalizedRecoverySuggestionErrorKey,
                                  nil];
        *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                        code: BXEmulatedMT32MissingROM
                                    userInfo: userInfo];
    }
    return NO;
}

- (BOOL) validateMT32ControlROM: (NSString **)ioValue error: (NSError **)outError
{
    NSString *ROMPath = *ioValue;
    return [BXEmulatedMT32 typeOfControlROMAtPath: ROMPath error: outError] != BXMT32ROMTypeUnknown;
}

- (BOOL) validateMT32PCMROM: (NSString **)ioValue error: (NSError **)outError
{
    NSString *ROMPath = *ioValue;
    return [BXEmulatedMT32 typeOfPCMROMAtPath: ROMPath error: outError] != BXMT32ROMTypeUnknown;
}

@end
