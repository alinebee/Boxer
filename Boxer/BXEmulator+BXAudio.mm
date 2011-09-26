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


NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";


@implementation BXEmulator (BXAudio)

- (NSString *) _pathForMT32ROMNamed: (NSString *)ROMName
{
    ROMName = [ROMName lowercaseString];
    
    if ([ROMName isMatchedByRegex: @"control"])
    {
        return [[self delegate] pathToMT32ControlROMForEmulator: self];
    }
    else if ([ROMName isMatchedByRegex: @"pcm"])
    {
        return [[self delegate] pathToMT32PCMROMForEmulator: self];
    }
    else return nil;
}


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
        0x20, 0x00, 0x00,
        
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

- (BOOL) attachMIDIDeviceOfType: (BXMIDIDeviceType)type
                          error: (NSError **)outError
{
    id <BXMIDIDevice> device = [self MIDIDeviceForType: type error: outError];
    
    if (device)
    {
        NSLog(@"Setting active MIDI device to %@", device);
        [self setActiveMIDIDevice: device];
        return YES;
    }
    else
    {
        //TODO: send a message to our delegate informing them of our failure.
        if (type == BXMIDIDeviceTypeMT32)
        {
            NSLog(@"Could not initialize MT-32 emulation, falling back to standard MIDI synth.");
            [self setPreferredMIDIDeviceType: BXMIDIDeviceTypeGeneralMIDI];
            return [self attachMIDIDeviceOfType: BXMIDIDeviceTypeGeneralMIDI error: outError];
        }
        return NO;
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
    if ([self preferredMIDIDeviceType] == BXMIDIDeviceTypeAuto)
    {
        //If we receive an MT-32-specific sysex message, and we're set to auto-detect
        //the appropriate MIDI device type, then swap out our current MIDI device for
        //an emulated MT-32.
        if (![[self activeMIDIDevice] isKindOfClass: [BXEmulatedMT32 class]] &&
            [[self class] isMT32Sysex: message])
        {
            BOOL succeeded = [self attachMIDIDeviceOfType: BXMIDIDeviceTypeMT32 error: NULL];
    #ifdef BOXER_DEBUG
            if (succeeded)
            {
                [self sendMT32LCDMessage: @"Activating MT-32"];
            }
    #endif
        }
    }
    
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
    }
        
    [[self activeMIDIDevice] handleSysex: message];
}


+ (BOOL) isMT32Sysex: (NSData *)message
{
    //Too short to be a valid sysex message.
    if ([message length] < 5) return NO;
        
    const UInt8 *contents = (const UInt8 *)[message bytes];
    UInt8   manufacturerID  = contents[1],
            modelID         = contents[3],
            commandType     = contents[4],
            baseAddress     = contents[5];
    
    //Command is intended for a different device than a Roland MT-32.
    if (manufacturerID != BXGMManufacturerIDRoland) return NO;
    if (!(modelID == BXRolandSysexModelIDMT32 || BXRolandSysexModelIDD50)) return NO;
    
    //Some General MIDI drivers (used by Origin and Westwood among others)
    //send sysex messages telling the MT-32 to reset and setting up basic channel
    //and reverb settings: but will then proceed to deliver General MIDI music to
    //the MT-32 anyway. We want to ignore these messages, so that we don't
    //enable MT-32 emulation erroneously for those drivers.
    //(If the game is using these drivers but really does have MT-32 music then
    //it'll send more sysex messages than just these anyway, so we'll catch it.)
    if (commandType == BXRolandSysexDataSend &&
        (baseAddress == BXRolandSysexAddressReset || baseAddress == BXRolandSysexAddressSystemArea)) return NO;
    
    //If we got this far, then it's an MT-32 sysex we should care about.
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

@end
