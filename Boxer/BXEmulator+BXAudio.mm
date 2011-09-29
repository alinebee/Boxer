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
#import "BXMIDISynth.h"



NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";


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

- (id <BXMIDIDevice>) MIDIDeviceForType: (BXMIDIDeviceType)type
                                  error: (NSError **)outError
{
    id <BXMIDIDevice> device = nil;
    
    //First, see what the delegate has to say: if it provides us with a MIDI device,
    //we don't need to bother.
    device = [[self delegate] MIDIDeviceForType: type];
    
    if (!device)
    {
        switch (type)
        {
            case BXMIDIDeviceTypeNone:
                device = nil;
                break;
                
            case BXMIDIDeviceTypeExternal:
                device = [[BXExternalMIDIDevice alloc] initWithDestinationAtIndex: 0
                                                                            error: outError];
                break;
                
            case BXMIDIDeviceTypeMT32:
                {
                NSString *PCMROMPath        = [[self delegate] pathToMT32PCMROMForEmulator: self];
                NSString *controlROMPath    = [[self delegate] pathToMT32ControlROMForEmulator: self];
                
                device = [[BXEmulatedMT32 alloc] initWithPCMROM: PCMROMPath
                                                     controlROM: controlROMPath
                                                       delegate: self
                                                          error: outError];
                }
                break;
                
            case BXMIDIDeviceTypeGeneralMIDI:
            default:
                device = [[BXMIDISynth alloc] initWithError: outError];
                break;
                
        }
        [device autorelease];
    }
    return device;
}

- (id <BXMIDIDevice>) attachMIDIDeviceOfType: (BXMIDIDeviceType)type
                                       error: (NSError **)outError
{
    NSError *error = nil;
    id <BXMIDIDevice> device = [self MIDIDeviceForType: type error: &error];
    
    if (device)
    {
        [self setActiveMIDIDevice: device];
        return device;
    }
    else
    {
        if ([[error domain] isEqualToString: BXEmulatedMT32ErrorDomain])
        {
            //If an MT-32 emulator cannot be created, then fall back on the regular MIDI synth.
            //Disable our auto-detection at the same time, so we won't keep trying to create an
            //emulated MT-32 if we keep picking up MT-32 messages from the game.
            //TODO: send a message to our delegate informing them of our failure, and let them
            //handle this logic.
            
            [self setPreferredMIDIDeviceType: BXMIDIDeviceTypeGeneralMIDI];
            return [self attachMIDIDeviceOfType: BXMIDIDeviceTypeGeneralMIDI error: outError];
        }
        else
        {
            if (outError) *outError = error;
            return nil;
        }
    }
}

- (void) sendMIDIMessage: (NSData *)message
{
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
    }
    
    if ([self activeMIDIDevice])
    {
        //If we're not ready to send yet, wait until we are.
        [self _waitUntilActiveMIDIDeviceIsReady];
        [[self activeMIDIDevice] handleMessage: message];
    }
}

- (void) sendMIDISysex: (NSData *)message
{
    if ([self _shouldAutodetectMT32])
    {
        //Check if the message we've received is intended for an MT-32,
        //and if so, how 'conclusive' it is that the game is playing MT-32 music.
        BOOL confirmsSupport, isMT32Sysex = [[self class] isMT32Sysex: message
                                                indicatingMT32Support: &confirmsSupport];
        if (isMT32Sysex)
        {
            //If this sysex conclusively indicates that the game is playing MT-32 music,
            //swap to the emulated MT-32 immediately and deliver any messages it missed.
            if (confirmsSupport)
            {
                id device = [self attachMIDIDeviceOfType: BXMIDIDeviceTypeMT32 error: NULL];
                if ([device supportsMT32Music])
                {
#ifdef BOXER_DEBUG
                    [self sendMT32LCDMessage: @"    MT-32 Active    "];
#endif
                    [self _flushPendingSysexMessages];
                }
                else [self _clearPendingSysexMessages];
            }
            //Otherwise, queue up the sysex so that we can deliver it to the emulated MT-32
            //later if we decide to switch, ensuring it won't miss out on any startup commands.
            else
            {
                [self _queueSysexMessage: message];
            }
        }
    }
    
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
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
        
        //Some MIDI files (so far, only Strike Commander's) contain embedded display
        //messages: these should be treated as inconclusive.
        else if (commandType == BXRolandSysexDataSend && baseAddress == BXRolandSysexAddressDisplay) *indicatesSupport = NO;
        
        else *indicatesSupport = YES;
    }
    
    return YES;
}


#pragma mark -
#pragma mark Private methods

- (BOOL) _shouldAutodetectMT32
{
    //Only try to autodetect the MT-32 if no explicit MIDI type was specified for this game,
    //and if we're not already sending to a MIDI device that supports MT-32 music.
    if ([self preferredMIDIDeviceType] != BXMIDIDeviceTypeAuto) return NO;
    if ([[self activeMIDIDevice] supportsMT32Music]) return NO;
    
    return YES;
}

- (void) _resetMIDIDeviceDetection
{
    [self _clearPendingSysexMessages];
    if ([self preferredMIDIDeviceType] == BXMIDIDeviceTypeAuto)
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

@end
