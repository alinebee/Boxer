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


#pragma mark -
#pragma mark Private constants

#define BXGMManufacturerIDRoland 0x41
#define BXGMManufacturerIDNonRealtime 0x7E
#define BXGMManufacturerIDRealtime 0x7F

#define BXRolandSysexModelIDMT32 0x16
#define BXRolandSysexModelIDD50 0x14

#define BXRolandSysexDeviceIDDefault 0x10

#define BXRolandSysexDataRequest 0x11
#define BXRolandSysexDataSend 0x12

#define BXRolandSysexAddressSystemArea 0x10
#define BXRolandSysexAddressReset 0x7F
#define BXRolandSysexAddressDisplay 0x20


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
        BXSysExStart,
        
        BXGMManufacturerIDRoland, BXRolandSysexDeviceIDDefault, BXRolandSysexModelIDMT32,
        
        BXRolandSysexDataSend,
        
        //We're sending a display-on-LCD message
        BXRolandSysexAddressDisplay, 0x00, 0x00,
        
        //The 20-character message, which we'll fill in later
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        
        //The checksum, which we'll replace later
        0xFF,
        
        BXSysExEnd
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
            NSString *PCMROMPath = [[self delegate] pathToMT32PCMROMForEmulator: self];
            NSString *controlROMPath = [[self delegate] pathToMT32ControlROMForEmulator: self];
            
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
    return [device autorelease];
}

- (id <BXMIDIDevice>) attachMIDIDeviceOfType: (BXMIDIDeviceType)type
                                       error: (NSError **)outError
{
    id <BXMIDIDevice> device = [self MIDIDeviceForType: type error: outError];
    
    if (device)
    {
        [self setActiveMIDIDevice: device];
        return device;
    }
    else
    {
        if (type == BXMIDIDeviceTypeMT32)
        {
            //Disable our auto-detection so we don't keep trying to create an emulated MT-32.
            //TODO: send a message to our delegate informing them of our failure.
            [self setPreferredMIDIDeviceType: BXMIDIDeviceTypeGeneralMIDI];
            return [self attachMIDIDeviceOfType: BXMIDIDeviceTypeGeneralMIDI error: outError];
        }
        else return nil;
    }
}

- (void) sendMIDIMessage: (NSData *)message
{
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
    }
    [[self activeMIDIDevice] handleMessage: message];
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
                if ([device isKindOfClass: [BXEmulatedMT32 class]])
                {
                    [self _flushPendingSysexMessages];
#ifdef BOXER_DEBUG
                    [self sendMT32LCDMessage: @"    MT-32 Active    "];
#endif
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
        
    [[self activeMIDIDevice] handleSysex: message];
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
    if (manufacturerID != BXGMManufacturerIDRoland) return NO;
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

+ (BOOL) isGeneralMIDISysex: (NSData *)message
{
    //Too short to be a valid SysEx message
    if ([message length] < 5) return NO;
    
    const UInt8 *contents = (const UInt8 *)[message bytes];
    UInt8 manufacturerID = contents[1];
    
    //These manufacturer IDs are reserved for manufacturer-agnostic General MIDI messages
    //supported by any GM-compliant device.
    return manufacturerID == BXGMManufacturerIDRealtime || manufacturerID == BXGMManufacturerIDNonRealtime;
}


#pragma mark -
#pragma mark Private methods

- (BOOL) _shouldAutodetectMT32
{
    return [self preferredMIDIDeviceType] == BXMIDIDeviceTypeAuto && ![[self activeMIDIDevice] isKindOfClass: [BXEmulatedMT32 class]];
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
    NSLog(@"Queueing sysex: %@", message);
    //Copy the message before queuing, as it may be backed by a buffer we don't own.
    [pendingSysexMessages addObject: [NSData dataWithData: message]];
}

- (void) _flushPendingSysexMessages
{
    if ([self activeMIDIDevice])
    {
        for (NSData *message in pendingSysexMessages)
        {
            [[self activeMIDIDevice] handleSysex: message];
        }
    }
    [self _clearPendingSysexMessages];
}

- (void) _clearPendingSysexMessages
{
    [pendingSysexMessages removeAllObjects];
}

@end
