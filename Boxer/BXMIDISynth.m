/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMIDISynth.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXMIDISynth ()

@property (readwrite, copy, nonatomic) NSString *soundFontPath;

- (BOOL) _prepareAudioGraphWithError: (NSError **)outError;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXMIDISynth
@synthesize soundFontPath = _soundFontPath;


#pragma mark -
#pragma mark Initialization and cleanup

- (id <BXMIDIDevice>) initWithError: (NSError **)outError
{
    if ((self = [self init]))
    {
        if (![self _prepareAudioGraphWithError: outError])
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void) dealloc
{
    [self close];
    
    self.soundFontPath = nil;
    
    [super dealloc];
}

- (void) close
{
    if (_graph)
    {
        AUGraphStop(_graph);
        DisposeAUGraph(_graph);
    }
    _graph = NULL;
    _synthUnit = NULL;
    _outputUnit = NULL;
}


- (BOOL) _prepareAudioGraphWithError: (NSError **)outError
{
    AudioComponentDescription outputDesc, synthDesc;
    AUNode outputNode, synthNode;
    
    //OS X's default CoreAudio output
    outputDesc.componentType = kAudioUnitType_Output;
    outputDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
    outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputDesc.componentFlags = 0;
    outputDesc.componentFlagsMask = 0;
    
    //OS X's built-in MIDI synth
    synthDesc.componentType = kAudioUnitType_MusicDevice;
    synthDesc.componentSubType = kAudioUnitSubType_DLSSynth;
    synthDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    synthDesc.componentFlags = 0;
    synthDesc.componentFlagsMask = 0;
    
    OSStatus errCode = noErr;
    
#define REQUIRE(result) if ((errCode = result) != noErr) break
    
    do {
        REQUIRE(NewAUGraph(&_graph));
        //Create nodes for our input synth and our output, and connect them together
        REQUIRE(AUGraphAddNode(_graph, &outputDesc, &outputNode));
        REQUIRE(AUGraphAddNode(_graph, &synthDesc, &synthNode));
        REQUIRE(AUGraphConnectNodeInput(_graph, synthNode, 0, outputNode, 0));
        
        //Open and initialize the graph and its units
        REQUIRE(AUGraphOpen(_graph));
        REQUIRE(AUGraphInitialize(_graph));
        
        //Get proper references to the audio units for the synth.
        REQUIRE(AUGraphNodeInfo(_graph, synthNode, NULL, &_synthUnit));
        REQUIRE(AUGraphNodeInfo(_graph, outputNode, NULL, &_outputUnit));
        
        //Finally start processing the graph.
        //(Technically, we could move this to the first time we receive a MIDI message.)
        REQUIRE(AUGraphStart(_graph));
    }
    while (NO);
    
    if (errCode)
    {
        //Clean up after ourselves if there was an error
        if (_graph)
        {
            DisposeAUGraph(_graph);
            _graph = NULL;
            _synthUnit = NULL;
            _outputUnit = NULL;
        }
        
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                            code: errCode
                                        userInfo: nil];
        }
        return NO;
    }
    return YES;
}


#pragma mark -
#pragma mark MIDI processing and status

- (BOOL) supportsMT32Music          { return NO; }
- (BOOL) supportsGeneralMIDIMusic   { return YES; }


//The MIDI synth is *always* ready to party
- (BOOL) isProcessing       { return NO; }
- (NSDate *) dateWhenReady  { return [NSDate distantPast]; }


- (BOOL) loadSoundFontAtPath: (NSString *)path
                       error: (NSError **)outError
{
    NSAssert(_synthUnit != NULL, @"loadSoundFontAtPath:error: called before successful initialization.");
    
    path = path.stringByStandardizingPath;
    
    if (![path isEqualToString: self.soundFontPath])
    {
        OSStatus errCode = noErr;
        
        //Clear any existing soundfont
        if (path == nil)
        {
            errCode = AudioUnitSetProperty(_synthUnit,
                                           kMusicDeviceProperty_SoundBankFSRef,
                                           kAudioUnitScope_Global,
                                           0,
                                           NULL,
                                           0
                                           );
        }
        //Load a new soundfont
        else
        {
            FSRef soundfontRef;
            errCode = FSPathMakeRef((const UInt8 *)path.fileSystemRepresentation, &soundfontRef, NULL);
            
            if (errCode == noErr)
            {
                errCode = AudioUnitSetProperty(_synthUnit,
                                               kMusicDeviceProperty_SoundBankFSRef,
                                               kAudioUnitScope_Global,
                                               0,
                                               &soundfontRef,
                                               sizeof(soundfontRef)
                                               );
            }
        }
        
        if (errCode)
        {
            if (outError)
            {
                NSDictionary *userInfo = path ? [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey] : nil;
                *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                                code: errCode
                                            userInfo: userInfo];
            }
            return NO;
        }
        else
        {
            self.soundFontPath = path;
            return YES;
        }
    }
    else return NO;
}

- (void) handleMessage: (NSData *)message
{
    NSAssert(_synthUnit != NULL, @"handleMessage: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleMessage:");
    
    UInt8 *contents = (UInt8 *)[message bytes];
    UInt8 status = contents[0];
    UInt8 data1 = ([message length] > 1) ? contents[1] : 0;
    UInt8 data2 = ([message length] > 2) ? contents[2] : 0;
    
    MusicDeviceMIDIEvent(_synthUnit, status, data1, data2, 0);
}

- (void) handleSysex: (NSData *)message
{
    NSAssert(_synthUnit != NULL, @"handleSysEx: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleSysex:");
    
    MusicDeviceSysEx(_synthUnit, (UInt8 *)message.bytes, message.length);
}

- (void) pause
{
    NSAssert(_graph != NULL, @"pause called before successful initialization.");
    AUGraphStop(_graph);
}

- (void) resume
{
    NSAssert(_graph != NULL, @"resume called before successful initialization.");
    AUGraphStart(_graph);
}

- (void) setVolume: (float)volume
{
    NSAssert(_outputUnit != NULL, @"setVolume: called before successful initialization.");
    AudioUnitSetParameter(_outputUnit, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, volume, 0);
}

- (float) volume
{
    NSAssert(_outputUnit != NULL, @"volume called before successful initialization.");
    
    AudioUnitParameterValue volume;
    OSStatus errCode = AudioUnitGetParameter(_outputUnit, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, &volume);
    return (!errCode) ? volume : 0.0f;
}

@end
