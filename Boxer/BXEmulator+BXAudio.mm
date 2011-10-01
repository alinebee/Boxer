/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "RegexKitLite.h"
#import "BXEmulatedMT32.h"
#import "BXExternalMIDIDevice.h"
#import "BXExternalMT32.h"
#import "BXMIDISynth.h"



NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";

NSString * const BXMIDIMusicTypeKey                 = @"MIDI Music Type";
NSString * const BXMIDIPreferExternalKey            = @"Prefer External MIDI Device";
NSString * const BXMIDIExternalDeviceIndexKey       = @"External Device Index";
NSString * const BXMIDIExternalDeviceUniqueIDKey    = @"External Device Unique ID";
NSString * const BXMIDIExternalDeviceNeedsMT32SysexDelaysKey = @"Needs MT-32 Sysex Delays";


@implementation BXEmulator (BXAudio)

- (void) emulatedMT32: (BXEmulatedMT32 *)MT32 didDisplayMessage: (NSString *)message
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: message forKey: @"message"];
    [self _postNotificationName: BXEmulatorDidDisplayMT32MessageNotification
               delegateSelector: @selector(emulatorDidDisplayMT32Message:)
                       userInfo: userInfo];
}

- (void) sendMT32LCDMessage: (NSString *)message
{
#define MSG_LENGTH 20
#define SYSEX_LENGTH 30
#define SYSEX_ADDRESS_OFFSET 5
#define SYSEX_MSG_OFFSET 8
#define SYSEX_CHECKSUM_OFFSET SYSEX_LENGTH - 2
    
    //Crop the message to 14 characters
    if ([message length] > MSG_LENGTH)
        message = [message substringToIndex: MSG_LENGTH];
    
    //Get a dump of the message's bytes, crushed down to ASCII encoding
    NSData *chars = [message dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: YES];
    
    unsigned char sysex[SYSEX_LENGTH] = {
        BXSysexStart,
        
        BXSysexManufacturerIDRoland, BXRolandSysexDeviceIDDefault, BXRolandSysexModelIDMT32,
        
        BXRolandSysexDataSend,
        
        //We're sending a display-on-LCD message
        BXRolandSysexAddressDisplay, 0x00, 0x00,
        
        //The 20-character message, which we'll fill in later
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        
        //The checksum, which we'll replace later
        0xFF,
        
        BXSysexEnd
    };
    
    //Paste the message into the sysex
    [chars getBytes: &sysex[SYSEX_MSG_OFFSET] length: MSG_LENGTH];
    
    //Calculate the checksum for the sysex,
    //which is based on the address and message bytes
    NSUInteger i, checksum = 0;
    for (i = SYSEX_ADDRESS_OFFSET; i < SYSEX_CHECKSUM_OFFSET; i++)
    {
        checksum += sysex[i];
    }
    checksum = 128 - (checksum % 128);
    sysex[SYSEX_CHECKSUM_OFFSET] = checksum;
    
    [self sendMIDISysex: [NSData dataWithBytes: sysex length: SYSEX_LENGTH]];
}


# pragma mark -
# pragma mark MIDI output handling

- (BXMIDIMusicType) musicType
{
    return [[[self requestedMIDIDeviceDescription] objectForKey: BXMIDIMusicTypeKey] integerValue];
}

- (id <BXMIDIDevice>) attachMIDIDeviceForDescription: (NSDictionary *)description
{
    id <BXMIDIDevice> device = [[self delegate] MIDIDeviceForEmulator: self
                                                   meetingDescription: description];
    
    [self setActiveMIDIDevice: device];
    return device;
}

- (void) sendMIDIMessage: (NSData *)message
{
    //Connect to our requested MIDI device the first time we need one.
    [self _attachRequestedMIDIDeviceIfNeeded];
    
    if ([self activeMIDIDevice])
    {
        //If we're not ready to send yet, wait until we are.
        [self _waitUntilActiveMIDIDeviceIsReady];
        [[self activeMIDIDevice] handleMessage: message];
    }
}

- (void) sendMIDISysex: (NSData *)message
{
    //Connect to our requested MIDI device the first time we need one.
    [self _attachRequestedMIDIDeviceIfNeeded];
    
    //Autodetect if the music we're receiving would be suitable for an MT-32:
    //If so, and our current device can't play MT-32 music, try switching to one that can.
    if ([self _shouldAutodetectMT32])
    {
        //Check if the message we've received was intended for an MT-32,
        //and if so, how 'conclusive' it is that the game is playing MT-32 music.
        BOOL supportConfirmed, isMT32Sysex = [[self class] isMT32Sysex: message
                                                 indicatingMT32Support: &supportConfirmed];
        if (isMT32Sysex)
        {
            //If this sysex conclusively indicates that the game is playing MT-32 music,
            //then try to swap in an MT-32-supporting device immediately.
            if (supportConfirmed)
            {
                NSDictionary *description = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithInteger: BXMIDIMusicMT32], BXMIDIMusicTypeKey,
                                             nil];
                
                id device = [self attachMIDIDeviceForDescription: description];
                
                //If the new device does indeed support the MT-32 (i.e., we didn't fail
                //to create one and fall back on something else) then send it the MT-32
                //messages it missed.
                if ([device supportsMT32Music])
                {
#ifdef BOXER_DEBUG
                    [self sendMT32LCDMessage: @"BOXER:::MT-32 Active"];
#endif
                    [self _flushPendingSysexMessages];
                }
                //If we couldn't attach an MT-32-supporting MIDI device, then disable
                //autodetection so we don't keep trying.
                else
                {
                    [self setAutodetectsMT32: NO];
                    [self _clearPendingSysexMessages];
                }
            }
            //If we couldn't yet confirm that the game is playing MT-32 music, queue up
            //the MT-32 sysex we received so that we can deliver it to an MT-32 device
            //later. This ensures it won't miss out on any startup commands.
            else
            {
                [self _queueSysexMessage: message];
            }
        }
    }

    if ([self activeMIDIDevice])
    {
        //If we're not ready to send yet, wait until we are.
        [self _waitUntilActiveMIDIDeviceIsReady];
        [[self activeMIDIDevice] handleSysex: message];
    }
}

+ (BOOL) isMT32Sysex: (NSData *)message indicatingMT32Support: (BOOL *)indicatesSupport
{
    if (indicatesSupport) *indicatesSupport = NO;
    
    //Too short to be a valid MT-32 sysex message.
    if ([message length] < 7) return NO;
        
    const UInt8 *contents = (const UInt8 *)[message bytes];
    UInt8   manufacturerID  = contents[1],
            modelID         = contents[3],
            commandType     = contents[4],
            baseAddress     = contents[5];
    
    //Command is intended for a different device than a Roland MT-32.
    if (manufacturerID != BXSysexManufacturerIDRoland) return NO;
    if (!(modelID == BXRolandSysexModelIDMT32 || modelID == BXRolandSysexModelIDD50)) return NO;
    
    if (indicatesSupport)
    {
        //Some General MIDI drivers (used by Origin and Westwood among others)
        //send sysexes telling the MT-32 to reset and setting up initial reverb
        //and volume settings: but will then proceed to deliver General MIDI music
        //to the MT-32 anyway.
        if (commandType == BXRolandSysexDataSend &&
            (baseAddress == BXRolandSysexAddressReset || baseAddress == BXRolandSysexAddressSystemArea)) *indicatesSupport = NO;
        
        //Some MIDI songs (so far, only Strike Commander's) contain embedded display
        //messages: these should be treated as inconclusive, since the songs are shared
        //between the game's MT-32 and General MIDI modes and these messages will be
        //sent even when the game is in General MIDI mode.
        else if (commandType == BXRolandSysexDataSend && baseAddress == BXRolandSysexAddressDisplay) *indicatesSupport = NO;
        
        else *indicatesSupport = YES;
    }
    
    return YES;
}


#pragma mark -
#pragma mark Private methods

- (void) setRequestedMIDIDeviceDescription: (NSDictionary *)newDescription
{
    if (![requestedMIDIDeviceDescription isEqual: newDescription])
    {
        [requestedMIDIDeviceDescription release];
        requestedMIDIDeviceDescription = [newDescription retain];
        
        //Enable MT-32 autodetection if the description doesn't have a specific music type in mind.
        BXMIDIMusicType musicType = [[newDescription objectForKey: BXMIDIMusicTypeKey] integerValue];
        [self setAutodetectsMT32: (musicType == BXMIDIMusicAutodetect)];
    }
}

- (BOOL) _shouldAutodetectMT32
{
    //Try to autodetect the MT-32 only if autodetection was enabled,
    //and if we don't already have a MIDI device that supports MT-32 music.
    return ([self autodetectsMT32] && ![[self activeMIDIDevice] supportsMT32Music]);
}

- (void) _resetMIDIDeviceDetection
{
    [self _clearPendingSysexMessages];
    //Clear the active MIDI device so that we can redetect it next time
    if ([self autodetectsMT32])
    {
        [self setActiveMIDIDevice: nil];
    }
}

- (void) _queueSysexMessage: (NSData *)message
{
    //Copy the message before queuing, as it may be backed by a buffer we don't own.
    [pendingSysexMessages addObject: [NSData dataWithData: message]];
}

- (void) _flushPendingSysexMessages
{
    if ([self activeMIDIDevice])
    {
        for (NSData *message in pendingSysexMessages)
        {
            //If we're not ready to send yet, wait until we are.
            [self _waitUntilActiveMIDIDeviceIsReady];
            [[self activeMIDIDevice] handleSysex: message];
        }
    }
    [self _clearPendingSysexMessages];
}

- (void) _clearPendingSysexMessages
{
    [pendingSysexMessages removeAllObjects];
}

- (void) _waitUntilActiveMIDIDeviceIsReady
{
    //TODO: pass this stall back on up to BXSession to handle, so it can
    //run the event loop while we wait.
    if ([[self activeMIDIDevice] isProcessing])
    {
        [NSThread sleepUntilDate: [[self activeMIDIDevice] dateWhenReady]];
    }
}

- (void) _attachRequestedMIDIDeviceIfNeeded
{
    NSDictionary *description = [self requestedMIDIDeviceDescription];
    BXMIDIMusicType musicType = [[description objectForKey: BXMIDIMusicTypeKey] integerValue];
    if (![self activeMIDIDevice] && musicType != BXMIDIMusicDisabled)
    {
        [self attachMIDIDeviceForDescription: [self requestedMIDIDeviceDescription]];
    }
}

@end
