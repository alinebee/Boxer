/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMIDIDevice.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXExternalMIDIDevice ()

- (BOOL) _connectToDestination: (MIDIEndpointRef)destination
                         error: (NSError **)outError;

- (BOOL) _connectToDestinationAtIndex: (ItemCount)index
                                error: (NSError **)outError;

- (BOOL) _connectToDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                   error: (NSError **)outError;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXExternalMIDIDevice

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
    OSStatus errCode = MIDIClientCreate((CFStringRef)[[self class] defaultClientName], NULL, NULL, &_client);
    
    if (errCode == noErr)
    {
        errCode = MIDIOutputPortCreate(_client, (CFStringRef)[[self class] defaultPortName], &_port);
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
#pragma mark MIDI processing

- (void) handleMessage: (NSData *)message
{
    NSAssert(_port && _destination, @"handleMessage: called before successful initialization.");
    NSAssert([message length] > 0, @"0-length message received by handleMessage:");
    
    UInt8 buffer[sizeof(MIDIPacketList)];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
	MIDIPacket *currentPacket = MIDIPacketListInit(packetList);
    
    MIDIPacketListAdd(packetList, sizeof(buffer), currentPacket, (MIDITimeStamp)0, [message length], (UInt8 *)[message bytes]);
    MIDISend(_port, _destination, packetList);
}

- (void) handleSysex: (NSData *)message
{
//The same length as DOSBox's MIDI message buffer, plus padding for extra data used by the packet list.
//(Technically a sysex message could be much longer than 1024 bytes, but it would be truncated by DOSBox
//before it ever reaches us.)
#define MAX_SYSEX_PACKET_SIZE 1024 * 4

    NSAssert(_port && _destination, @"handleMessage: called before successful initialization.");
    NSAssert([message length] > 0, @"0-length message received by handleMessage:");

    UInt8 buffer[MAX_SYSEX_PACKET_SIZE];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
	MIDIPacket *currentPacket = MIDIPacketListInit(packetList);
    
    MIDIPacketListAdd(packetList, sizeof(buffer), currentPacket, (MIDITimeStamp)0, [message length], (UInt8 *)[message bytes]);
    MIDISend(_port, _destination, packetList);
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
    
}

@end
