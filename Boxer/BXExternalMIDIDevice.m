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
    if (_port)
    {
        //Ensure the device stops playing notes before shutting down
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
    
    [super dealloc];
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

- (void) handleMessage: (const UInt8 *)message length: (NSUInteger)length
{
    NSAssert(_port && _destination, @"handleMessage:length: called before successful initialization.");
    
    UInt8 buffer[128];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
	MIDIPacket *currentPacket = MIDIPacketListInit(packetList);
    
    //Add message to the MIDIPacketList
    MIDIPacketListAdd(packetList, sizeof(buffer), currentPacket, (MIDITimeStamp)0, length, message);
    
    // Send the MIDIPacketList
    MIDISend(_port, _destination, packetList);

}

- (void) handleSysex: (const UInt8 *)message length: (NSUInteger)length
{
    //IMPLEMENTATION NOTE: we should send the message with MIDISendSysex,
    //which is asynchronous and designed for large datasets. However, that
    //would require us to copy the message ourselves (it's a buffer, so
    //DOSBox may overwrite the original) and manage the copy's lifecycle
    //beyond the scope of this function.
    //tl;dr version: MIDISend is slower but much much simpler.
    [self handleMessage: message length: length];
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
        [self handleMessage: message length: 3];
    }
}

- (void) resume
{
    
}

@end
