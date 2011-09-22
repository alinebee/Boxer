/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulatorPrivate.h"
#import "RegexKitLite.h"

void MIDI_RawOutByte(Bit8u data);

NSString * const BXEmulatorDidDisplayMT32MessageNotification = @"BXEmulatorDidDisplayMT32MessageNotification";

@implementation BXEmulator (BXAudio)

- (NSString *) _pathForMT32ROMNamed: (NSString *)ROMName
{
    if ([[self delegate] conformsToProtocol: @protocol(BXEmulatorMT32EmulationDelegate)])
    {
        ROMName = [ROMName lowercaseString];
        
        if ([ROMName isMatchedByRegex: @"control"])
        {
            return [(id)[self delegate] pathToMT32ControlROMForEmulator: self];
        }
        else if ([ROMName isMatchedByRegex: @"pcm"])
        {
            return [(id)[self delegate] pathToMT32PCMROMForEmulator: self];
        }
    }
    return nil;
}


- (void) _didDisplayMT32LCDMessage: (NSString *)message
{
    NSLog(@"%@", message);
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

@end
