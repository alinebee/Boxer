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
    
    [_soundFontPath release], _soundFontPath = nil;
    
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
    _unit = NULL;
}


- (BOOL) _prepareAudioGraphWithError: (NSError **)outError
{
    AUNode outputNode, synthNode;
    AudioComponentDescription outputDesc, synthDesc;
    
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
        
        //Get a reference to the audio unit for the synth.
        REQUIRE(AUGraphNodeInfo(_graph, synthNode, NULL, &_unit));
        
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
    NSAssert(_unit != NULL, @"loadSoundFontAtPath:error: called before successful initialization.");
    
    if (![path isEqualToString: _soundFontPath])
    {
        OSStatus errCode = noErr;
        
        //Clear an existing soundfont
        if (path == nil)
        {
            errCode = AudioUnitSetProperty(_unit,
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
            errCode = FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation], &soundfontRef, NULL);
            
            if (errCode == noErr)
            {
                errCode = AudioUnitSetProperty(_unit,
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
            [self willChangeValueForKey: @"soundFontPath"];
            [_soundFontPath release];
            _soundFontPath = [path retain];
            [self didChangeValueForKey: @"soundFontPath"];
            return YES;
        }
    }
    else return NO;
}

- (void) handleMessage: (NSData *)message
{
    NSAssert(_unit != NULL, @"handleMessage: called before successful initialization.");
    NSAssert([message length] > 0, @"0-length message received by handleMessage:");
    
    UInt8 *contents = (UInt8 *)[message bytes];
    UInt8 status = contents[0];
    UInt8 data1 = ([message length] > 1) ? contents[1] : 0;
    UInt8 data2 = ([message length] > 2) ? contents[2] : 0;
    
    MusicDeviceMIDIEvent(_unit, status, data1, data2, 0);
}

- (void) handleSysex: (NSData *)message
{
    NSAssert(_unit != NULL, @"handleSysEx: called before successful initialization.");
    NSAssert([message length] > 0, @"0-length message received by handleSysex:");
    
    MusicDeviceSysEx(_unit, (UInt8 *)[message bytes], [message length]);
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

//Unimplemented for now
- (void) setVolume: (float)volume
{
    //TODO: set volume on our output node
}

- (float) volume
{
    //TODO: retrieve volume from our output node
    return 1.0f;
}

@end
