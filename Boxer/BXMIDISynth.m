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
@synthesize soundFontPath;


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
    if (graph)
    {
        AUGraphStop(graph);
        DisposeAUGraph(graph);
    }
    graph = NULL;
    unit = NULL;
    
    [soundFontPath release], soundFontPath = nil;
    
    [super dealloc];
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
        REQUIRE(NewAUGraph(&graph));
        //Create nodes for our input synth and our output, and connect them together
        REQUIRE(AUGraphAddNode(graph, &outputDesc, &outputNode));
        REQUIRE(AUGraphAddNode(graph, &synthDesc, &synthNode));
        REQUIRE(AUGraphConnectNodeInput(graph, synthNode, 0, outputNode, 0));
        
        //Open and initialize the graph and its units
        REQUIRE(AUGraphOpen(graph));
        REQUIRE(AUGraphInitialize(graph));
        
        //Get a reference to the audio unit for the synth.
        REQUIRE(AUGraphNodeInfo(graph, synthNode, NULL, &unit));
        
        //Finally start processing the graph.
        //(Technically, we could move this to the first time we receive a MIDI message.)
        REQUIRE(AUGraphStart(graph));
    }
    while (NO);
    
    if (errCode)
    {
        //Clean up after ourselves if there was an error
        if (graph)
        {
            DisposeAUGraph(graph);
            graph = NULL;
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
#pragma mark MIDI processing

- (BOOL) loadSoundFontAtPath: (NSString *)path
                       error: (NSError **)outError
{
    NSAssert(unit != NULL, @"loadSoundFontAtPath:error: called before successful initialization.");
    
    if (![path isEqualToString: soundFontPath])
    {
        OSStatus errCode = noErr;
        
        //Clear an existing soundfont
        if (path == nil)
        {
            errCode = AudioUnitSetProperty(unit,
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
                errCode = AudioUnitSetProperty(unit,
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
            [soundFontPath release];
            soundFontPath = [path retain];
            [self didChangeValueForKey: @"soundFontPath"];
            return YES;
        }
    }
    else return NO;
}

- (void) handleMessage: (const UInt8 *)message
                length: (NSUInteger)length
{
    NSAssert(unit != NULL, @"handleMessage:length: called before successful initialization.");
    
    UInt8 status = message[0];
    UInt8 data1 = (length > 1) ? message[1] : 0;
    UInt8 data2 = (length > 2) ? message[2] : 0;
    
    MusicDeviceMIDIEvent(unit, status, data1, data2, 0);
}

- (void) handleSysex: (const UInt8 *)message length: (NSUInteger)length
{
    NSAssert(unit != NULL, @"handleSysEx:length: called before successful initialization.");
    
    MusicDeviceSysEx(unit, message, length);
}

- (void) pause
{
    NSAssert(graph != NULL, @"pause called before successful initialization.");
    AUGraphStop(graph);
}

- (void) resume
{
    NSAssert(graph != NULL, @"resume called before successful initialization.");
    AUGraphStart(graph);
}

@end
