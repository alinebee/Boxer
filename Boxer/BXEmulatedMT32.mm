/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedMT32.h"
#import "RegexKitLite.h"
#import "MT32Emu/Synth.h"
#import "MT32Emu/FileStream.h"
#import "BXEmulatedMT32Delegate.h"
#import "NSError+BXErrorHelpers.h"


#pragma mark -
#pragma mark Private constants

NSString * const BXEmulatedMT32ErrorDomain = @"BXEmulatedMT32ErrorDomain";
NSString * const BXMT32ControlROMTypeKey = @"BXMT32ControlROMTypeKey";
NSString * const BXMT32PCMROMTypeKey = @"BXMT32PCMROMTypeKey";


#define BXMT32ControlROMSize    64 * 1024
#define BXMT32PCMROMSize        512 * 1024
#define BXCM32LPCMROMSize       1024 * 1024
#define BXMT32DefaultSampleRate 32000



#pragma mark -
#pragma mark Private method declarations

@interface BXEmulatedMT32 ()
@property (retain, nonatomic) NSError *synthError;

- (BOOL) _prepareMT32EmulatorWithError: (NSError **)outError;
- (NSString *) _pathToROMMatchingName: (NSString *)ROMName;
- (void) _reportMT32MessageOfType: (MT32Emu::ReportType)type data: (const void *)reportData;

//Callbacks for MT32Emu::Synth
MT32Emu::File * _openMT32ROM(void *userData, const char *filename);
void _closeMT32ROM(void *userData, MT32Emu::File *file);
int _reportMT32Message(void *userData, MT32Emu::ReportType type, const void *reportData);
void _logMT32DebugMessage(void *userData, const char *fmt, va_list list);

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedMT32
@synthesize delegate = _delegate;
@synthesize PCMROMPath = _PCMROMPath;
@synthesize controlROMPath = _controlROMPath;
@synthesize synthError = _synthError;
@synthesize sampleRate = _sampleRate;


#pragma mark -
#pragma mark ROM validation methods

+ (unsigned long long) PCMSizeForROMType: (BXMT32ROMType)ROMType
{
    if (ROMType == BXMT32ROMTypeCM32L)
        return BXCM32LPCMROMSize;
    else
        return BXMT32PCMROMSize;
}

+ (BXMT32ROMType) typeOfControlROMAtPath: (NSString *)path
                                   error: (NSError **)outError
{
    if (outError) *outError = nil;
    
    if (!path)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32MissingROM
                                        userInfo: nil];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath: path];
	
	//File could not be opened for reading, bail out
	if (!file)
	{
		if (outError)
		{
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path
                                                                 forKey: NSFilePathErrorKey];
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32CouldNotReadROM
										userInfo: userInfo];
		}
		return BXMT32ROMTypeUnknown;
	}

    @try
    {
        //Measure how large the control ROM is
        [file seekToEndOfFile];
        unsigned long long fileSize = file.offsetInFile;
        [file seekToFileOffset: 0];
        
        //If the file matches our expected size for control ROMs, check what ROM type it is
        if (fileSize == BXMT32ControlROMSize)
        {
            NSString *ROMProfilePath = [[NSBundle mainBundle] pathForResource: @"MT32ROMTypes" ofType: @"plist"];
            NSArray *ROMProfiles = [NSArray arrayWithContentsOfFile: ROMProfilePath];
            
            for (NSDictionary *profile in ROMProfiles)
            {
                NSData *nameBytes = [[profile objectForKey: @"name"] dataUsingEncoding: NSASCIIStringEncoding];
                NSUInteger nameOffset = [[profile objectForKey: @"nameOffset"] unsignedIntegerValue];
                
                [file seekToFileOffset: nameOffset];
                NSData *bytesInROM = [file readDataOfLength: nameBytes.length];
                
                if ([bytesInROM isEqualToData: nameBytes])
                    return [[profile objectForKey: @"type"] unsignedIntegerValue];
            }
        }
    }
    //If we couldn't read data at any point, then bail out with an error. 
    @catch (NSException *exception)
    {
        if (outError)
		{
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey];
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32CouldNotReadROM
										userInfo: userInfo];
		}
        return BXMT32ROMTypeUnknown;
    }
    
    //If we got this far, the control ROM was the wrong size or not recognised as any of our known types.
    if (outError)
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path
                                                             forKey: NSFilePathErrorKey];
        
        *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                        code: BXEmulatedMT32InvalidROM
                                    userInfo: userInfo];
    }
    return nil;
}

+ (BXMT32ROMType) typeOfPCMROMAtPath: (NSString *)path
                               error: (NSError **)outError
{
    if (outError) *outError = nil;
    
    if (!path)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32MissingROM
                                        userInfo: nil];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath: path];
	
	//File could not be opened for reading, bail out
	if (!file)
	{
		if (outError)
		{
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey];
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32CouldNotReadROM
										userInfo: userInfo];
		}
		return BXMT32ROMTypeUnknown;
	}
    
    //Measure how large the file is, to determine what type of ROM it should be.
    //(It would be nice if we had a more authoritative heuristic than this, but
    //that's all MT32Emu::Synth uses to determine ROM viability.)
    
    [file seekToEndOfFile];
    unsigned long long fileSize = file.offsetInFile;
    [file seekToFileOffset: 0];
    
    if (fileSize == BXMT32PCMROMSize)
        return BXMT32ROMTypeMT32;
    else if (fileSize == BXCM32LPCMROMSize)
        return BXMT32ROMTypeCM32L;
    else
    {
        if (outError)
        {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey];
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32InvalidROM
                                        userInfo: userInfo];
        }
        return BXMT32ROMTypeUnknown;
    } 
}

+ (BXMT32ROMType) typeofROMPairWithControlROMPath: (NSString *)controlROMPath
                                       PCMROMPath: (NSString *)PCMROMPath 
                                            error: (NSError **)outError
{
    NSError *controlError = nil, *PCMError = nil;
    
    //Validate both ROMs individually.
    BXMT32ROMType controlType   = [self typeOfControlROMAtPath: controlROMPath
                                                         error: (outError) ? &controlError : NULL];
    
    BXMT32ROMType PCMType       = [self typeOfPCMROMAtPath: PCMROMPath
                                                     error: (outError) ? &PCMError : NULL];
    
    //If the ROM types could be determined and did match, we have a winner
    if (controlType != BXMT32ROMTypeUnknown && controlType == PCMType) return controlType;
    
    //Otherwise, work out what went wrong
    else
    {
        if (outError)
        {   
            //If one or the other ROM was invalid, then treat that as the canonical error.
            if ([controlError matchesDomain: BXEmulatedMT32ErrorDomain code: BXEmulatedMT32InvalidROM])
                *outError = controlError;
            
            else if ([PCMError matchesDomain: BXEmulatedMT32ErrorDomain code: BXEmulatedMT32InvalidROM])
                *outError = PCMError;
            
            //Otherwise, return the first error we got.
            else if (controlError)
                *outError = controlError;
            
            else if (PCMError)
                *outError = PCMError;
            
            //If there were no actual errors, but the ROM types didn't match,
            //then flag this as a mismatch.
            else
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInteger: controlType], BXMT32ControlROMTypeKey,
                                          [NSNumber numberWithInteger: PCMType], BXMT32PCMROMTypeKey,
                                          nil];
                
                *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                code: BXEmulatedMT32MismatchedROMs
                                            userInfo: userInfo];
            }
        }
        return BXMT32ROMTypeUnknown;
    }
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXMIDIDevice>) initWithPCMROM: (NSString *)PCMROM
                          controlROM: (NSString *)controlROM
                            delegate: (id <BXEmulatedMT32Delegate>)delegate
                               error: (NSError **)outError
{
    self = [self init];
    if (self)
    {
        self.PCMROMPath = PCMROM;
        self.controlROMPath = controlROM;
        self.sampleRate = BXMT32DefaultSampleRate;
        self.delegate = delegate;
        
        if (![self _prepareMT32EmulatorWithError: outError])
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void) close
{
    if (_synth)
    {
        _synth->close();
        delete _synth;
        _synth = NULL;
    }
}

- (void) dealloc
{
    [self close];
    
    self.synthError = nil;
    self.PCMROMPath = nil;
    self.controlROMPath = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark MIDI processing and status

- (BOOL) supportsMT32Music          { return YES; }
- (BOOL) supportsGeneralMIDIMusic   { return NO; }

//Since we're processing on the same thread, the emulator is always ready to go
- (BOOL) isProcessing       { return NO; }
- (NSDate *) dateWhenReady  { return [NSDate distantPast]; }


- (void) handleMessage: (NSData *)message
{
    NSAssert(_synth, @"handleMessage: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleMessage:");
    
    //MT32Emu's playMsg takes standard 3-byte MIDI messages as a 32-bit integer, which
    //is a terrible idea, but there you go. Thus we pack our byte array into such an
    //integer, ensuring we keep the expected byte order.
    
    //IMPLEMENTATION NOTE: we use bitwise here, rather than just casting the array
    //to a UInt32, to avoid endianness bugs on PowerPC.
    UInt8 *contents = (UInt8 *)message.bytes;
    UInt8 status = contents[0];
    UInt8 data1 = (message.length > 1) ? contents[1] : 0;
    UInt8 data2 = (message.length > 2) ? contents[2] : 0;
    
    UInt32 packedMsg = status + (data1 << 8) + (data2 << 16);
    
    _synth->playMsg(packedMsg);
}

- (void) handleSysex: (NSData *)message
{
    NSAssert(_synth, @"handleSysEx: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleSysex:");
    
    _synth->playSysex((UInt8 *)message.bytes, (UInt32)message.length);
}

- (void) resume
{
    //Because BXEmulatedMT32 is mixer-driven, this has no effect
}

- (void) pause
{
    //Because BXEmulatedMT32 is mixer-driven, this has no effect
}

//Because BXEmulatedMT32 is mixer-driven, this has no effect:
//it is up to the renderer to control volume.
- (void) setVolume: (float)volume
{
    
}

- (float) volume
{
    return 1.0f;
}

- (BOOL) renderOutputToBuffer: (void *)buffer 
                       frames: (NSUInteger)numFrames
                   sampleRate: (NSUInteger *)sampleRate
                       format: (BXAudioFormat *)format
{
    _synth->render((SInt16 *)buffer, (UInt32)numFrames);

    *sampleRate = self.sampleRate;
    *format = BXAudioFormat16Bit | BXAudioFormatSigned | BXAudioFormatStereo;
    return YES;
}


#pragma mark -
#pragma mark Private methods

- (BOOL) _prepareMT32EmulatorWithError: (NSError **)outError
{
    //Bail out early if we haven't been told where to find the necessary ROMs
    if (!self.PCMROMPath || !self.controlROMPath)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32MissingROM
                                        userInfo: nil];
        }
        return NO;
    }
    
    _synth = new MT32Emu::Synth();
    
    MT32Emu::SynthProperties properties;
    
    properties.userData = self;
    properties.report = &_reportMT32Message;
    properties.openFile = &_openMT32ROM;
    properties.closeFile = &_closeMT32ROM;
    properties.printDebug = &_logMT32DebugMessage;
    properties.sampleRate = self.sampleRate;
    properties.baseDir = NULL;
    
    if (!_synth->open(properties))
    {
        //Pick up the initialization error we'll have received from
        //the callback, and post it back upstream
        if (outError)
            *outError = self.synthError;

        delete _synth;
        return NO;
    }
    
    return YES;
}

- (NSString *) _pathToROMMatchingName: (NSString *)ROMName
{
    ROMName = ROMName.lowercaseString;
    if ([ROMName isMatchedByRegex: @"control"])
    {
        return self.controlROMPath;
    }
    else if ([ROMName isMatchedByRegex: @"pcm"])
    {
        return self.PCMROMPath;
    }
    else return nil;
}

- (void) _reportMT32MessageOfType: (MT32Emu::ReportType)type data: (const void *)reportData
{
    switch (type) {
        case MT32Emu::ReportType_lcdMessage:
            //Pass LCD messages on to our delegate
            {
                NSString *message = [NSString stringWithCString: (const char *)reportData
                                                       encoding: NSASCIIStringEncoding];
                [self.delegate emulatedMT32: self didDisplayMessage: message];
            }
            break;
        
        case MT32Emu::ReportType_errorControlROM:
        case MT32Emu::ReportType_errorPCMROM:
            //If ROM loading failed, record the error that occurred so we can retrieve it back in the initializer.
            {
                NSString *ROMPath;
                if (type == MT32Emu::ReportType_errorControlROM)
                    ROMPath = self.controlROMPath;
                else
                    ROMPath = self.PCMROMPath;
                
                NSDictionary *userInfo = nil;
                if (ROMPath) userInfo = [NSDictionary dictionaryWithObject: ROMPath
                                                                    forKey: NSFilePathErrorKey];
                
                [self setSynthError: [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                         code: BXEmulatedMT32InvalidROM
                                                     userInfo: userInfo]];
            }
            break;
            
        default:
            break;
    }
}


#pragma mark -
#pragma mark C++-facing callbacks


MT32Emu::File * _openMT32ROM(void *userData, const char *filename)
{
    NSString *requestedROMName = [NSString stringWithUTF8String: filename];
    NSString *ROMPath = [(__bridge BXEmulatedMT32 *)userData _pathToROMMatchingName: requestedROMName];
    
    if (ROMPath)
    {
        MT32Emu::FileStream *file = new MT32Emu::FileStream();
        BOOL opened = file->open(ROMPath.fileSystemRepresentation);
        if (!opened)
        {
            delete file;
            return NULL;
        }
        else return file;
    }
    else return NULL;
}

void _closeMT32ROM(void *userData, MT32Emu::File *file)
{
    file->close();
}

int _reportMT32Message(void *userData, MT32Emu::ReportType type, const void *reportData)
{
    [(__bridge BXEmulatedMT32 *)userData _reportMT32MessageOfType: type data: reportData];
    return 0;
}

void _logMT32DebugMessage(void *userData, const char *fmt, va_list list)
{
#ifdef BOXER_DEBUG
    NSLogv([NSString stringWithCString: fmt encoding: NSASCIIStringEncoding], list);
#endif
}

@end
