/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMIDIDevice.h"
#import "BXExternalMIDIDevice+BXGeneralMIDISysexes.h"

#pragma mark -
#pragma mark Private method declarations

@interface BXExternalMIDIDevice ()

- (BOOL) _connectToDestination: (MIDIEndpointRef)destination
                         error: (NSError **)outError;

- (BOOL) _connectToDestinationAtIndex: (ItemCount)index
                                error: (NSError **)outError;

- (BOOL) _connectToDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                   error: (NSError **)outError;

//The callback for our volume synchronization timer.
//Calls syncVolume and invalidates the timer.
- (void) _performVolumeSync: (NSTimer *)timer;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXExternalMIDIDevice
@synthesize dateWhenReady = _dateWhenReady;
@synthesize destination = _destination;
@synthesize volume = _volume;
@synthesize requestedVolume = _requestedVolume;

#pragma mark -
#pragma mark Class helper methods

+ (NSString *) defaultClientName
{
    return NSLocalizedString(@"Boxer",
                             @"Descriptive name for Boxer’s MIDI client when communicating with external MIDI devices.");
}

+ (NSString *) defaultPortName
{
    return NSLocalizedString(@"Boxer MIDI Out",
                             @"Descriptive name for Boxer’s MIDI output port when communicating with external MIDI devices.");
}

#pragma mark -
#pragma mark Initialization and cleanup

- (id <BXMIDIDevice>) init
{
    if ((self = [super init]))
    {
        //Don't use setVolume:, as it will try to send a message.
        _volume = 1.0f;
        _requestedVolume = 1.0f;
        self.dateWhenReady = [NSDate distantPast];
        _secondsPerByte = BXExternalMIDIDeviceDefaultSysexRate;
    }
    return self;
}


- (id <BXMIDIDevice>) initWithDestination: (MIDIEndpointRef)destination
                                    error: (NSError **)outError
{
    if ((self = [self init]))
    {
        BOOL succeeded = [self _connectToDestination: destination error: outError];
        if (!succeeded)
        {
            [self release];
            self = nil;
        }
    }
    return self;
}


- (id <BXMIDIDevice>) initWithDestinationAtIndex: (ItemCount)destIndex
                                           error: (NSError **)outError
{
    if ((self = [self init]))
    {
        BOOL succeeded = [self _connectToDestinationAtIndex: destIndex
                                                      error: outError];
        if (!succeeded)
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id <BXMIDIDevice>) initWithDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                              error: (NSError **)outError
{
    if ((self = [self init]))
    {
        BOOL succeeded = [self _connectToDestinationAtUniqueID: uniqueID
                                                         error: outError];
        if (!succeeded)
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
    
    self.dateWhenReady = nil;
    
    [super dealloc];
}

- (void) close
{
    if (_port)
    {
        //Ensure the device stops playing notes when closing
        [self pause];
        
        MIDIPortDispose(_port);
        _port = NULL;
    }
    
    if (_client)
    {
        MIDIClientDispose(_client);
        _client = NULL;
    }
    
    //This does not need disposing, because we did not create it ourselves
    _destination = NULL;
}

- (BOOL) _connectToDestination: (MIDIEndpointRef)destination
                         error: (NSError **)outError
{
    //Create a MIDI client and port
    OSStatus errCode = MIDIClientCreate((CFStringRef)[self class].defaultClientName, NULL, NULL, &_client);
    
    if (errCode == noErr)
    {
        errCode = MIDIOutputPortCreate(_client, (CFStringRef)[self class].defaultPortName, &_port);
    }
    
    if (errCode != noErr)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                            code: errCode
                                        userInfo: nil];
        }
        if (_client)
        {
            MIDIClientDispose(_client);
            _client = NULL;
        }
        return NO;
    }
    
    _destination = destination;
    
    //Determine the speed at which we should send to this destination
    SInt32 maxSysexSpeed = 0;
    errCode = MIDIObjectGetIntegerProperty(destination, kMIDIPropertyMaxSysExSpeed, &maxSysexSpeed);
    if (errCode == noErr)
    {
        _secondsPerByte = 1.0f / (NSTimeInterval)maxSysexSpeed;
    }
    
    return YES;
}

- (BOOL) _connectToDestinationAtIndex: (ItemCount)destIndex
                                error: (NSError **)outError
{
    ItemCount numDestinations = MIDIGetNumberOfDestinations();
    MIDIEndpointRef destination = NULL;
    if (destIndex < numDestinations)
        destination = MIDIGetDestination(destIndex);
    
    if (!destination)
    {
        if (outError)
        {
            //Paraphrasing a little, but this error code seems appropriate.
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                            code: kMIDIObjectNotFound
                                        userInfo: nil];
        }
        return NO;
    }
    else return [self _connectToDestination: destination error: outError];
}


- (BOOL) _connectToDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                   error: (NSError **)outError
{
    MIDIEndpointRef destination;
    MIDIObjectType type;
    OSStatus errCode = MIDIObjectFindByUniqueID(uniqueID, (MIDIObjectRef)&destination, &type);
    
    if (errCode == noErr && type != kMIDIObjectType_Destination)
        errCode = kMIDIObjectNotFound;
    
    if (errCode != noErr)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                            code: errCode
                                        userInfo: nil];
        }
        return NO;
    }
    else return [self _connectToDestination: destination error: outError];
}

#pragma mark -
#pragma mark MIDI processing and status

- (NSTimeInterval) processingDelayForSysex: (NSData *)sysex
{
    return _secondsPerByte * sysex.length;
}

- (BOOL) supportsMT32Music
{
    //Technically we don't know, so this is a 'maybe'.
    return YES;
}

- (BOOL) supportsGeneralMIDIMusic
{
    //Technically we don't know, so this is a 'maybe'.
    return YES;
}

- (BOOL) isProcessing
{
    //We're still processing if our readiness date is in the future
    return self.dateWhenReady.timeIntervalSinceNow > 0;
}


- (void) handleMessage: (NSData *)message
{
    NSAssert(_port && _destination, @"handleMessage: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleMessage:");
    
    UInt8 buffer[sizeof(MIDIPacketList)];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
	MIDIPacket *currentPacket = MIDIPacketListInit(packetList);
    
    MIDIPacketListAdd(packetList, sizeof(buffer), currentPacket, (MIDITimeStamp)0, message.length, (UInt8 *)message.bytes);
    
    MIDISend(_port, _destination, packetList);
}

- (void) handleSysex: (NSData *)message
{
    //Sniff the sysex to see if it's a request to set the master volume.
    //If so, capture the volume and substitute our own sysex containing our scaled volume.
    float requestedVolume;
    if ([[self class] isMasterVolumeSysex: message withVolume: &requestedVolume])
    {
        self.requestedVolume = requestedVolume;
        [self syncVolume];
    }
    else
    {
        [self dispatchSysex: message];
        
        //Sniff the sysex to see if it's a message that would reset the device's master volume.
        if ([[self class] sysexResetsMasterVolume: message])
        {
            self.requestedVolume = 1.0f;
            [self scheduleVolumeSync];
        }
    }
}

- (void) dispatchSysex: (NSData *)message
{
//The same length as DOSBox's MIDI message buffer, plus padding for extra data used by the packet list.
//(Technically a sysex message could be much longer than 1024 bytes, but it would be truncated by DOSBox
//before it ever reaches us.)
#define MAX_SYSEX_PACKET_SIZE 1024 * 4

    NSAssert(_port && _destination, @"handleMessage: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleMessage:");

    UInt8 buffer[MAX_SYSEX_PACKET_SIZE];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
	MIDIPacket *currentPacket = MIDIPacketListInit(packetList);
    
    MIDIPacketListAdd(packetList, sizeof(buffer), currentPacket, (MIDITimeStamp)0, message.length, (UInt8 *)message.bytes);
    
    MIDISend(_port, _destination, packetList);
    
    //Now, calculate how long it should take the device to process all that
    NSTimeInterval processingDelay = [self processingDelayForSysex: message];
    if (processingDelay > 0)
        self.dateWhenReady = [NSDate dateWithTimeIntervalSinceNow: processingDelay];
}

- (void) pause
{
    //Send All Notes Off signals to channels 0-15 to kill any lingering notes.
    //This has been tested on an MT-32 and is valid according to the MIDI spec:
    //http://www.midi.org/techspecs/midimessages.php
	
    UInt8 message[3] = {BXChannelModeChangePrefix, BXAllNotesOffMessage, 0};
    NSUInteger i, numChannels = 16;
    
    for (i = 0; i < numChannels; i++)
    {
        //Add the channel number to the mode-change prefix
        //to get the proper mode-change message for that channel.
        message[0] = BXChannelModeChangePrefix + i;
        [self handleMessage: [NSData dataWithBytes: message length: 3]];
    }
}

- (void) resume
{
    //No resume message is needed, instead we'll resume playing once new MIDI data comes in.
}

- (void) setVolume: (float)volume
{
    NSAssert(_port && _destination, @"setVolume: called before successful initialization.");
    
    volume = MIN(1.0f, volume);
    volume = MAX(0.0f, volume);
    
    if (self.volume != volume)
    {
        _volume = volume;
        [self scheduleVolumeSync];
    }
}

- (void) setRequestedVolume: (float)volume
{
    volume = MIN(1.0f, volume);
    volume = MAX(0.0f, volume);
    
    _requestedVolume = volume;
}

- (void) scheduleVolumeSync
{
    //If we already have a timer in progress, don't reschedule.
    if (!_volumeSyncTimer)
    {
        NSTimeInterval timeUntilReady = MAX(0.0, self.dateWhenReady.timeIntervalSinceNow);
        NSTimeInterval syncDelay = timeUntilReady + BXVolumeSyncDelay;
        
        //No need to retain it, since it'll be retained by the runloop until it fires
        _volumeSyncTimer = [NSTimer scheduledTimerWithTimeInterval: syncDelay
                                                            target: self
                                                          selector: @selector(_performVolumeSync:)
                                                          userInfo: nil
                                                           repeats: NO];
    }
}

- (void) _performVolumeSync: (NSTimer *)timer
{
    //Invalidate and clear our sync timer.
    [_volumeSyncTimer invalidate];
    _volumeSyncTimer = nil;
    
    //Only try to sync the volume if we're still connected.
    if (_port && _destination)
    {   
        //If we're still busy processing, then defer the sync until after another delay.
        if (self.isProcessing)
            [self scheduleVolumeSync];
        else
            [self syncVolume];
    }
}

- (void) syncVolume
{
    //If this method gets called manually, cancel the timer and clear it.
    [_volumeSyncTimer invalidate];
    _volumeSyncTimer = nil;
    
    NSData *volumeMessage = [[self class] sysexWithMasterVolume: self.volume * self.requestedVolume];
    [self dispatchSysex: volumeMessage];
}

@end
