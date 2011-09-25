/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatedMT32.h"
#import "RegexKitLite.h"
#import "MT32Emu/Filestream.h"
#import "BXEmulatedMT32Delegate.h"


NSString * const BXEmulatedMT32ErrorDomain = @"BXEmulatedMT32ErrorDomain";


#pragma mark -
#pragma mark Private method declarations

@interface BXEmulatedMT32 ()
@property (retain, nonatomic) NSError *synthError;

- (BOOL) _prepareMT32EmulatorWithError: (NSError **)outError;
- (void) _renderOutputForLength: (NSUInteger)length;
- (NSString *) _pathToROMMatchingName: (NSString *)ROMName;
- (void) _reportMT32MessageOfType: (MT32Emu::ReportType)type data: (const void *)reportData;

//Callbacks for MT32Emu::Synth and DOSBox mixer
MT32Emu::File * _openMT32ROM(void *userData, const char *filename);
void _closeMT32ROM(void *userData, MT32Emu::File *file);
int _reportMT32Message(void *userData, MT32Emu::ReportType type, const void *reportData);
void _logMT32DebugMessage(void *userData, const char *fmt, va_list list);
void _renderOutput(Bitu len);

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedMT32
@synthesize delegate = _delegate;
@synthesize PCMROMPath = _PCMROMPath, controlROMPath = _controlROMPath;
@synthesize synthError = _synthError;

BXEmulatedMT32 *_currentEmulatedMT32;

- (id <BXMIDIDevice>) initWithPCMROM: (NSString *)PCMROM
                          controlROM: (NSString *)controlROM
                            delegate: (id <BXEmulatedMT32Delegate>)delegate
                               error: (NSError **)outError
{
    if ((self = [self init]))
    {
        [self setPCMROMPath: PCMROM];
        [self setControlROMPath: controlROM];
        [self setDelegate: delegate];
        
        if (![self _prepareMT32EmulatorWithError: outError])
        {
            [self release];
            self = nil;
        }
        else
        {
            _currentEmulatedMT32 = self;
        }
    }
    return self;
}

- (void) dealloc
{
    if (_synth)
    {
        _synth->close();
        delete _synth;
        _synth = NULL;
    }
    
    if (_mixerChannel)
    {
        _mixerChannel->Enable(false);
        MIXER_DelChannel(_mixerChannel);
        _mixerChannel = NULL;
    }
    
    [self setSynthError: nil], [_synthError release];
    [self setPCMROMPath: nil], [_PCMROMPath release];
    [self setControlROMPath: nil], [_controlROMPath release];
    
    
    if (_currentEmulatedMT32 == self) _currentEmulatedMT32 = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark MIDI processing

- (void) handleMessage: (const UInt8 *)message length: (NSUInteger)length
{
    NSAssert(_synth, @"handleMessage:length: called before successful initialization.");
    
    //MT32Emu's synth takes messages as a 32-bit integer, which is a terrible idea, but there you go.
    //We need to convert our byte array to such, and allow for differing endianness on PowerPC Macs.
    UInt8 paddedMsg[4] = { message[0], message[1], message[2], 0};
    UInt32 intMsg = ((UInt32 *)paddedMsg)[0];
    
    _synth->playMsg(CFSwapInt32LittleToHost(intMsg));
}

- (void) handleSysex: (const UInt8 *)message length: (NSUInteger)length
{
    NSAssert(_synth, @"handleSysEx:length: called before successful initialization.");
    if (message[0] == 0xf0) _synth->playSysex(message, length);
    else _synth->playSysexWithoutFraming(message, length);
}

- (void) resume
{
    NSAssert(_mixerChannel, @"resume called before successful initialization.");
    _mixerChannel->Enable(YES);
}

- (void) pause
{
    NSAssert(_mixerChannel, @"pause called before successful initialization.");
    _mixerChannel->Enable(NO);
}


#pragma mark -
#pragma mark Private methods

- (BOOL) _prepareMT32EmulatorWithError: (NSError **)outError
{
    //Bail out early if we haven't been told where to find the necessary ROMs
    if (![self PCMROMPath] || ![self controlROMPath])
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
    properties.sampleRate = 32000;
    properties.baseDir = NULL;
    
    if (!_synth->open(properties))
    {
        //Pick up the initialization error we'll have received from
        //the callback, and post it back upstream
        if (outError) *outError = [self synthError];

        delete _synth;
        return NO;
    }
    
    _mixerChannel = MIXER_AddChannel(_renderOutput,properties.sampleRate, "MT32");
    _mixerChannel->Enable(YES);
    
    return YES;
}

- (void) _renderOutputForLength: (NSUInteger)length
{
    NSAssert(_synth && _mixerChannel, @"_renderOutputForLength: called before successful initialization.");
    
    Bit16s buffer[MIXER_BUFSIZE];
    
    _synth->render(buffer, length);
    _mixerChannel->AddSamples_s16(length, buffer);
}

- (NSString *) _pathToROMMatchingName: (NSString *)ROMName
{
    ROMName = [ROMName lowercaseString];
    if ([ROMName isMatchedByRegex: @"control"])
    {
        return [self controlROMPath];
    }
    else if ([ROMName isMatchedByRegex: @"pcm"])
    {
        return [self PCMROMPath];
    }
    else return nil;
}

- (void) _reportMT32MessageOfType: (MT32Emu::ReportType)type data: (const void *)reportData
{
    if (type == MT32Emu::ReportType_lcdMessage)
    {
        //Pass on LCD messages to our delegate
        NSString *message = [NSString stringWithUTF8String: (const char *)reportData];
        [[self delegate] emulatedMT32: self didDisplayMessage: message];
    }
    else if (type == MT32Emu::ReportType_errorControlROM || type == MT32Emu::ReportType_errorPCMROM)
    {
        //If ROM loading failed, record the error that occurred so we can retrieve it back in the initializer.
        NSString *ROMPath = (type == MT32Emu::ReportType_errorControlROM) ? [self controlROMPath] : [self PCMROMPath]; 
        NSDictionary *userInfo = ROMPath ? [NSDictionary dictionaryWithObject: ROMPath forKey: NSFilePathErrorKey] : nil;
        
        [self setSynthError: [NSError errorWithDomain: BXEmulatedMT32ErrorDomain
                                                 code: BXEmulatedMT32CouldNotLoadROM
                                             userInfo: userInfo]];
    }
    else
    {
#ifdef BOXER_DEBUG
        NSLog(@"MT-32 message of type: %d", type);
#endif
    }
}


#pragma mark -
#pragma mark C++-facing callbacks


MT32Emu::File * _openMT32ROM(void *userData, const char *filename)
{
    NSString *requestedROMName = [NSString stringWithUTF8String: filename];
    NSString *ROMPath = [(BXEmulatedMT32 *)userData _pathToROMMatchingName: requestedROMName];
    
    if (ROMPath)
    {
        MT32Emu::FileStream *file = new MT32Emu::FileStream();
        if (!file->open([ROMPath fileSystemRepresentation]))
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
    [(BXEmulatedMT32 *)userData _reportMT32MessageOfType: type data: reportData];
    return 0;
}

void _logMT32DebugMessage(void *userData, const char *fmt, va_list list)
{
#ifdef BOXER_DEBUG
    NSLogv([NSString stringWithUTF8String: fmt], list);
#endif
}

//Called periodically by DOSBox's mixer to fill its buffer with audio data.
void _renderOutput(Bitu len)
{
    //We need to use a hacky global variable for this because DOSBox's mixer
    //doesn't pass any context with its callbacks.
    [_currentEmulatedMT32 _renderOutputForLength: len];
}

@end
