/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorErrors.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXDrive.h"
#include <execinfo.h>

#pragma mark -
#pragma mark Private constants

NSString * const BXEmulatorErrorDomain      = @"BXEmulatorErrorDomain";
NSString * const BXDOSFilesystemErrorDomain = @"BXDOSFilesystemErrorDomain";
NSString * const BXDOSFilesystemErrorDriveKey = @"BXDOSFilesystemErrorDriveKey";

NSString * const BXEmulatorUnrecoverableException = @"BXEmulatorUnrecoverableException";

@implementation BXEmulatorCouldNotReadDriveError

+ (id) errorWithDrive: (BXDrive *)drive
{
    NSString *displayName = [[drive path] lastPathComponent];
	NSString *descriptionFormat = NSLocalizedString(@"The file “%1$@” could not be read.",
													@"Error shown when a drive's source path does not exist or could not be accessed. %1$@ is the filename of the drive's source path.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName];
    NSString *suggestion    = NSLocalizedString(@"Ensure that you have permission to access this file and that the volume containing it is still available.", @"Recovery suggestion shown when a drive's source path does not exist or could not be accessed.");
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemCouldNotReadDrive
                        userInfo: userInfo];
}
@end

@implementation BXEmulatorInvalidImageError

+ (id) errorWithDrive: (BXDrive *)drive
{
    NSString *displayName = [[drive path] lastPathComponent];
	NSString *descriptionFormat = NSLocalizedString(@"The disk image “%1$@” could not be opened.",
													@"Error shown when a drive's source image could not be loaded by DOSBox. %1$@ is the filename of the image.");
    
    NSString *suggestion    = NSLocalizedString(@"The disk image file may be corrupted or incomplete.", @"Recovery suggestion shown when a drive's source image could not be loaded by DOSBox.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemInvalidImage
                        userInfo: userInfo];
}
@end

@implementation BXEmulatorDriveLetterOccupiedError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *descriptionFormat = NSLocalizedString(@"There is already another drive at the DOS drive letter %1$@.",
													@"Error shown when a drive's letter is already occupied. %1$@ is the occupied drive letter.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, drive.letter];
    NSString *suggestion    = NSLocalizedString(@"Eject the existing drive and try again.", @"Recovery suggestion shown when a drive's letter is already occupied.");
    //TODO: a failure handler that offers to do that for the user
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemDriveLetterOccupied
                        userInfo: userInfo];
}
@end


@implementation BXEmulatorOutOfDriveLettersError

+ (id) errorWithDrive: (BXDrive *)drive
{	
	NSString *description	= NSLocalizedString(@"There are no free DOS drive letters remaining.",
                                                @"Error shown when all drive letters are already occupied.");
    NSString *suggestion    = NSLocalizedString(@"Eject one or more existing drives and try again.", @"Recovery suggestion shown when all drive letters are already occupied.");
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemOutOfDriveLetters
                        userInfo: userInfo];
}
@end


@implementation BXEmulatorNonContiguousDrivesError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *description	= NSLocalizedString(@"CD-ROM drives must be on sequential drive letters, with no gaps between them.",
                                                @"Error shown when the chosen drive letter for a CD-ROM drive would be non-contiguous.");
    NSString *suggestion    = NSLocalizedString(@"Try removing later drives before adding or removing any other CD-ROM drives.", @"Recovery suggestion shown when the chosen drive letter for a CD-ROM drive would be non-contiguous.");
    //TODO: a failure handler that offers to rearrange them for the user.
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemMSCDEXNonContiguousDrives
                        userInfo: userInfo];
}
@end


@implementation BXEmulatorOutOfCDROMDrivesError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *descriptionFormat	= NSLocalizedString(@"MS-DOS is limited to a maximum of %1$d CD-ROM drives.",
                                                    @"Error shown when the user tries to add more than the maximum number of CD-ROM drives. %1$d is the maximum number allowed.");
    
    NSString *description   = [NSString stringWithFormat: descriptionFormat, BXMaxCDROMDrives];
    NSString *suggestion    = NSLocalizedString(@"Eject one or more existing drives and try again.", @"Recovery suggestion shown when the user tries to add more than the maximum number of CD-ROM drives.");
    //TODO: a failure handler that offers to rearrange them for the user.
    
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              suggestion, NSLocalizedRecoverySuggestionErrorKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemMSCDEXOutOfCDROMDrives
                        userInfo: userInfo];
}
@end


@implementation BXEmulatorDriveLockedError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *descriptionFormat = NSLocalizedString(@"Drive %1$@ is required by Boxer and cannot be ejected.",
													@"Error shown when a drive was locked and cannot be ejected. %1$@ is the drive's letter.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, drive.letter];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              drive, BXDOSFilesystemErrorDriveKey,
                              nil];
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemDriveLocked
                        userInfo: userInfo];
}
@end


@implementation BXEmulatorDriveInUseError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *descriptionFormat = NSLocalizedString(@"Drive %1$@ (%2$@) is currently busy and cannot be ejected.",
													@"Error shown when a drive was in use and cannot be ejected. %1$@ is the drive's letter, and %2$@ its user-visible label.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, drive.letter, drive.title];
    
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: description,
                               BXDOSFilesystemErrorDriveKey: drive,
                               };
    
    return [self errorWithDomain: BXDOSFilesystemErrorDomain
                            code: BXDOSFilesystemDriveInUse
                        userInfo: userInfo];
}
@end


@interface BXEmulatorException ()

@property (retain, nonatomic) NSArray *callStackReturnAddresses;
@property (retain, nonatomic) NSArray *callStackSymbols;

@end

@implementation BXEmulatorException
@synthesize callStackReturnAddresses = _BXCallStackReturnAddresses;
@synthesize callStackSymbols = _BXCallStackSymbols;

+ (id) exceptionWithName: (NSString *)name exceptionInfo: (BXExceptionInfo)info
{
    return [[[self alloc] initWithName: name exceptionInfo: info] autorelease];
}

- (id) initWithName: (NSString *)name exceptionInfo: (BXExceptionInfo)exceptionInfo
{
    NSString *fileName      = [NSString stringWithUTF8String: exceptionInfo.fileName];
    NSString *functionName  = [NSString stringWithUTF8String: exceptionInfo.function];
    NSString *reason        = [NSString stringWithUTF8String: exceptionInfo.failureReason];
    NSInteger lineNumber    = exceptionInfo.lineNumber;
    
    NSMutableDictionary *errorInfo = [NSMutableDictionary dictionaryWithCapacity: 4];
    if (fileName)
    {
        [errorInfo setObject: fileName forKey: @"file"];
    }
    
    if (functionName)
    {
        [errorInfo setObject: functionName forKey: @"function"];
        [errorInfo setObject: @(lineNumber) forKey: @"line"];
    }

    self = [self initWithName: name reason: reason userInfo: errorInfo];
    if (self)
    {
        NSUInteger i, numAddresses = exceptionInfo.backtraceSize;
        if (numAddresses > 0)
        {
            char **symbolDescriptions = backtrace_symbols(exceptionInfo.backtraceAddresses, numAddresses);
            
            NSMutableArray *addresses   = [NSMutableArray arrayWithCapacity: numAddresses];
            NSMutableArray *symbols     = [NSMutableArray arrayWithCapacity: numAddresses];
            
            for (i = 0; i < numAddresses; i++)
            {
                NSUInteger addr = (NSUInteger)exceptionInfo.backtraceAddresses[i];
                const char *symbol = symbolDescriptions[i];
                if (symbol)
                {
                    NSString *desc = [NSString stringWithUTF8String: symbol];
                    [symbols addObject: desc];
                    [addresses addObject: @(addr)];
                }
            }
            
            self.callStackReturnAddresses = addresses;
            self.callStackSymbols = symbols;
            
            free(symbolDescriptions);
        }
    }
    return self;
}

- (void) dealloc
{
    self.callStackSymbols = nil;
    self.callStackReturnAddresses = nil;
    [super dealloc];
}

@end