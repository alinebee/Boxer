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
#import "NSError+ADBErrorHelpers.h"
#import "NSURL+ADBFilesystemHelpers.h"


#pragma mark -
#pragma mark Private constants

NSString * const BXEmulatedMT32ErrorDomain = @"BXEmulatedMT32ErrorDomain";
NSString * const BXMT32ControlROMTypeKey = @"BXMT32ControlROMType";
NSString * const BXMT32PCMROMTypeKey = @"BXMT32PCMROMType";

#define BXMT32DefaultSampleRate 32000



#pragma mark -
#pragma mark Private method declarations

@interface BXEmulatedMT32 ()
@property (retain, nonatomic) NSError *synthError;

- (BOOL) _prepareMT32EmulatorWithError: (NSError **)outError;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedMT32
@synthesize delegate = _delegate;
@synthesize PCMROMURL = _PCMROMURL;
@synthesize controlROMURL = _controlROMURL;
@synthesize synthError = _synthError;
@synthesize sampleRate = _sampleRate;


#pragma mark - ROM validation methods

+ (BXMT32ROMType) typeOfROMAtURL: (NSURL *)URL
                           error: (out NSError **)outError
{
    BOOL exists = [URL checkResourceIsReachableAndReturnError: NULL];
    if (!exists)
    {
        if (outError)
        {
            NSDictionary *userInfo = nil;
            if (URL) userInfo = @{ NSURLErrorKey: URL };
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32MissingROM
										userInfo: userInfo];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    MT32Emu::FileStream *file = new MT32Emu::FileStream();
    bool opened = file->open(URL.fileSystemRepresentation);
    if (!opened)
    {
        delete file;
        if (outError)
        {
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32CouldNotReadROM
										userInfo: @{ NSURLErrorKey: URL }];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    const MT32Emu::ROMInfo *info = MT32Emu::ROMInfo::getROMInfo(file);
    if (info == NULL)
    {
        delete file;
        if (outError)
        {
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32InvalidROM
										userInfo: @{ NSURLErrorKey: URL }];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    BOOL isControlROM = (info->type == MT32Emu::ROMInfo::Control);
    BOOL isCM32L = (strstr(info->shortName, "cm32l") != NULL);
    
    BXMT32ROMType type = (isControlROM ? BXMT32ROMIsControl : BXMT32ROMIsPCM);
    type |= (isCM32L ? BXMT32ROMIsCM32L : BXMT32ROMIsMT32);
    
    delete file;
    MT32Emu::ROMInfo::freeROMInfo(info);
    
    return type;
}

+ (BXMT32ROMType) typeOfROMPairWithControlROMURL: (NSURL *)controlROMURL
                                       PCMROMURL: (NSURL *)PCMROMURL
                                           error: (out NSError **)outError
{
    NSError *controlError = nil, *PCMError = nil;
    
    //Validate both ROMs individually.
    BXMT32ROMType controlType   = [self typeOfROMAtURL: controlROMURL error: &controlError];
    BXMT32ROMType PCMType       = [self typeOfROMAtURL: PCMROMURL error: &PCMError];
    
    //If either type could not be determined, bail out now.
    if (controlType == BXMT32ROMTypeUnknown || PCMType == BXMT32ROMTypeUnknown)
    {
        if (outError)
        {
            //If one or the other ROM was invalid, then treat that as the canonical error.
            if ([controlError matchesDomain: BXEmulatedMT32ErrorDomain code: BXEmulatedMT32InvalidROM])
                *outError = controlError;
            
            else if ([PCMError matchesDomain: BXEmulatedMT32ErrorDomain code: BXEmulatedMT32InvalidROM])
                *outError = PCMError;
            
            //Otherwise, return the first error we got from the check.
            else if (controlError)
                *outError = controlError;
            
            else if (PCMError)
                *outError = PCMError;
        }
        return BXMT32ROMTypeUnknown;
    }
    
    //If either ROM was not the expected type, bail out also.
    else if (!(controlType & BXMT32ROMIsControl))
    {
        if (outError)
        {
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32InvalidROM
										userInfo: @{ NSURLErrorKey: controlROMURL }];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    if (!(PCMType & BXMT32ROMIsPCM))
    {
        if (outError)
        {
			*outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
											code: BXEmulatedMT32InvalidROM
										userInfo: @{ NSURLErrorKey: controlROMURL }];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    //Finally, check if both ROMs were from the same model of MT-32.
    BOOL controlIsCM32L = (controlType & BXMT32ROMIsCM32L) == BXMT32ROMIsCM32L;
    BOOL PCMIsCM32L = (PCMType & BXMT32ROMIsCM32L) == BXMT32ROMIsCM32L;
    if (controlIsCM32L != PCMIsCM32L)
    {
        if (outError)
        {
            NSDictionary *userInfo = @{BXMT32ControlROMTypeKey: @(controlType),
                                       BXMT32PCMROMTypeKey: @(PCMType)};
            
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32MismatchedROMs
                                        userInfo: userInfo];
        }
        return BXMT32ROMTypeUnknown;
    }
    
    //If we got this far, both ROMs are a valid pair.
    return (controlIsCM32L) ? BXMT32ROMIsCM32L : BXMT32ROMIsMT32;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXMIDIDevice>) initWithPCMROM: (NSURL *)PCMROMURL
                          controlROM: (NSURL *)controlROMURL
                            delegate: (id <BXEmulatedMT32Delegate>)delegate
                               error: (NSError **)outError
{
    self = [self init];
    if (self)
    {
        self.PCMROMURL = PCMROMURL;
        self.controlROMURL = controlROMURL;
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
    
    if (_reportHandler)
    {
        delete _reportHandler;
        _reportHandler = NULL;
    }
    
    if (_PCMROMImage)
    {
        MT32Emu::ROMImage::freeROMImage(_PCMROMImage);
        delete _PCMROMHandle;
        _PCMROMImage = NULL;
        _PCMROMHandle = NULL;
    }
    
    if (_controlROMImage)
    {
        MT32Emu::ROMImage::freeROMImage(_controlROMImage);
        delete _controlROMHandle;
        _controlROMImage = NULL;
        _controlROMHandle = NULL;
    }
}

- (void) dealloc
{
    [self close];
    
    self.synthError = nil;
    self.PCMROMURL = nil;
    self.controlROMURL = nil;
    
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
    if (!self.PCMROMURL || !self.controlROMURL)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                            code: BXEmulatedMT32MissingROM
                                        userInfo: nil];
        }
        return NO;
    }
    
    //Coooool I love really awkward C++ APIs
    _reportHandler = new BXEmulatedMT32ReportHandler(self);
    _synth = new MT32Emu::Synth(_reportHandler);
    
    _PCMROMHandle = new MT32Emu::FileStream();
    _PCMROMHandle->open(self.PCMROMURL.fileSystemRepresentation);
    
    _controlROMHandle = new MT32Emu::FileStream();
    _controlROMHandle->open(self.controlROMURL.fileSystemRepresentation);
    
    _controlROMImage = MT32Emu::ROMImage::makeROMImage(_controlROMHandle);
    _PCMROMImage = MT32Emu::ROMImage::makeROMImage(_PCMROMHandle);
    
    if (!_synth->open(*_controlROMImage, *_PCMROMImage))
    {
        //Pick up the initialization error we'll have received from
        //the callback, and post it back upstream
        if (outError)
            *outError = self.synthError;

        //Clean up any resources that were created during failed initialization.
        [self close];
        return NO;
    }
    
    return YES;
}

@end


#pragma mark MT-32 emulator callbacks

void BXEmulatedMT32ReportHandler::onErrorControlROM()
{
    NSURL *URL = _delegate.controlROMURL;
    NSDictionary *userInfo = nil;
    if (URL)
        userInfo = @{ NSURLErrorKey: URL };
    
    _delegate.synthError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                               code: BXEmulatedMT32InvalidROM
                                           userInfo: userInfo];
}

void BXEmulatedMT32ReportHandler::onErrorPCMROM()
{
    NSURL *URL = _delegate.PCMROMURL;
    NSDictionary *userInfo = nil;
    if (URL)
        userInfo = @{ NSURLErrorKey: URL };
    
    _delegate.synthError = [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                               code: BXEmulatedMT32InvalidROM
                                           userInfo: userInfo];
}

void BXEmulatedMT32ReportHandler::showLCDMessage(const char *cMessage)
{
    NSString *message = [NSString stringWithCString: cMessage encoding: NSASCIIStringEncoding];
    [_delegate.delegate emulatedMT32: _delegate didDisplayMessage: message];
}

void BXEmulatedMT32ReportHandler::printDebug(const char *fmt, va_list list)
{
#ifdef BOXER_DEBUG
    NSLogv([NSString stringWithCString: fmt encoding: NSASCIIStringEncoding], list);
#endif
}