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

#define BXManufacturerIDRoland 0x41
#define BXModelIDRolandMT32 0x16
#define BXModelIDRolandD50 0x14

NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";


void MIDI_RawOutByte(Bit8u data);

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

- (id) displayMT32LCDMessage: (NSString *)message
{
#define MSG_LENGTH 20
#define SYSEX_LENGTH 30
#define SYSEX_ADDRESS_OFFSET 5
#define SYSEX_MSG_OFFSET 8
#define SYSEX_CHECKSUM_OFFSET SYSEX_LENGTH - 2

    //Strip surrounding quotes from the message
    message = [message stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"\""]];
    
    //Crop the message to 14 characters
    if ([message length] > MSG_LENGTH)
        message = [message substringToIndex: MSG_LENGTH];
    
    //Get a dump of the message's bytes, crushed down to ASCII encoding
    NSData *chars = [message dataUsingEncoding: NSASCIIStringEncoding allowLossyConversion: YES];
    
    unsigned char sysex[SYSEX_LENGTH] = {
        0xF0, //Sysex preamble
        
        //Manufacturer, device, model number
        0x41, 0x10, 0x16,
        
        //We're sending data
        0x12,
        
        //We're sending a display message
        0x20, 0x00, 0x00,
        
        //The 20-character message, which we'll fill in later
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
        
        //The checksum, which we'll replace later
        0xFF,
        
        0xF7 //Sysex leadout
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
    
    //Now, pipe the sysex bytes through DOSBox's MIDI mapper
    for (i = 0; i < SYSEX_LENGTH; i++)
    {
        MIDI_RawOutByte(sysex[i]);
    }
    
    return [NSNumber numberWithBool: YES];
}


# pragma mark -
# pragma mark MIDI output handling

- (id <BXMIDIDevice>) MIDIDeviceForType: (BXMIDIDeviceType)type error: (NSError **)outError
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

- (BOOL) isMT32SysEx: (uint8_t *)message length: (NSUInteger)length
{
    //Too short to be a valid SysEx message
    if (length < 5) return NO;
    
    UInt8 manufacturerID = message[1], modelID = message[3];
    
    //The MT-32 is also compatible with a subset of the Roland D-50's MIDI instruction set.
    return (manufacturerID == BXManufacturerIDRoland) && (modelID == BXModelIDRolandMT32 || modelID == BXModelIDRolandD50);
}

- (void) sendMIDIMessage: (uint8_t *)message length: (NSUInteger)length
{
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
    }
    [[self activeMIDIDevice] handleMessage: message length: length];
}

- (void) sendMIDISysEx: (uint8_t *)message length: (NSUInteger)length
{
    //If we receive an MT-32-specific sysex message, and we're set to auto-detect
    //the appropriate MIDI device type, then swap out our current MIDI device for
    //an emulated MT-32.
    if ([self isMT32SysEx: message length: length] && 
        [self preferredMIDIDeviceType] == BXMIDIDeviceTypeAuto &&
        ![[self activeMIDIDevice] isKindOfClass: [BXEmulatedMT32 class]])
    {
        [self attachMIDIDeviceOfType: BXMIDIDeviceTypeMT32 error: NULL];
    }
    
    //Connect a MIDI device the first time we need one
    if (![self activeMIDIDevice] && [self preferredMIDIDeviceType] != BXMIDIDeviceTypeNone)
    {
        [self attachMIDIDeviceOfType: [self preferredMIDIDeviceType] error: NULL];
    }
        
    [[self activeMIDIDevice] handleSysEx: message length: length];
}

@end
