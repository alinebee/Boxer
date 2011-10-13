/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMT32+BXMT32Sysexes.h"


@implementation BXExternalMT32 (BXMT32Sysexes)

#pragma mark -
#pragma mark Helper class methods

+ (BOOL) isMT32Sysex: (NSData *)sysex confirmingSupport: (BOOL *)supportConfirmed
{
    if (supportConfirmed) *supportConfirmed = NO;
    
    //Too short to be a valid MT-32 sysex message.
    if ([sysex length] < BXRolandSysexSendMinLength)
        return NO;
    
    const UInt8 *contents = (const UInt8 *)[sysex bytes];
    UInt8   manufacturerID  = contents[1],
    modelID         = contents[3],
    commandType     = contents[4],
    baseAddress     = contents[5];
    
    //Command is intended for a different device than a Roland MT-32.
    if (manufacturerID != BXSysexManufacturerIDRoland) return NO;
    if (!(modelID == BXRolandSysexModelIDMT32 || modelID == BXRolandSysexModelIDD50)) return NO;
    
    if (supportConfirmed)
    {
        //Some General MIDI drivers (used by Origin and Westwood among others)
        //send sysexes telling the MT-32 to reset and setting up initial reverb
        //and volume settings: but will then proceed to deliver General MIDI music
        //to the MT-32 anyway.
        if (commandType == BXRolandSysexSend && (baseAddress == BXMT32SysexAddressReset || baseAddress == BXMT32SysexAddressSystemArea))
            *supportConfirmed = NO;
        
        
        //If an LCD message is sent, check if it matches messages we know to ignore.
        else if (commandType == BXRolandSysexSend && baseAddress == BXMT32SysexAddressDisplay)
        {
            NSUInteger startOffset = BXRolandSysexHeaderLength + BXRolandSysexAddressLength;
            NSUInteger length = [sysex length] - BXRolandSysexTailLength - startOffset;
            
            NSData *messageData = [sysex subdataWithRange: NSMakeRange(startOffset, length)];
            NSString *message = [[NSString alloc] initWithData: messageData encoding: NSASCIIStringEncoding];
            
            NSArray *ignoredMessages = [NSArray arrayWithObjects:
                                       //Sent by Pacific Strike and Strike Commander in General MIDI mode
                                       @"SCSCSCFY!           ",
                                       nil];
            
            *supportConfirmed = (![ignoredMessages containsObject: message]);
            [message release];
        }
        
        else *supportConfirmed = YES;
    }
    
    return YES;
}

+ (NSData *) dataInSysex: (NSData *)sysex
{
    if ([sysex length] < BXRolandSysexSendMinLength) return nil;
    
    NSUInteger startOffset = BXRolandSysexHeaderLength + BXRolandSysexRequestLength;
    NSUInteger endOffset = [sysex length] - BXRolandSysexTailLength;
    
    NSRange payloadRange = NSMakeRange(startOffset, endOffset - startOffset);
    
    return [sysex subdataWithRange: payloadRange];
}

//Calculate the Roland checksum for the specified raw bytes.
+ (NSUInteger) _checksumForBytes: (UInt8 *)bytes length: (NSUInteger)length
{
    NSUInteger i, checksum = 0;
    for (i = 0; i < length; i++) checksum += bytes[i];
    
    checksum &= (BXRolandSysexChecksumModulus - 1);
    if (checksum) checksum = BXRolandSysexChecksumModulus - checksum;
    
    return checksum;    
}

+ (NSUInteger) checksumForSysex: (NSData *)sysex
{
    //An invalid sysex, for which we cannot generate a checksum
    if ([sysex length] < (BXRolandSysexHeaderLength + BXRolandSysexTailLength))
        return NSNotFound;
    
    //The checksum for a Roland sysex message is calculated from
    //the bytes of the message address and the message data:
    //skip the bytes before and after that block.
    UInt8 *bytes = (UInt8 *)[sysex bytes];
    
    NSUInteger length = [sysex length] - BXRolandSysexHeaderLength - BXRolandSysexTailLength;
    
    return [self _checksumForBytes: &bytes[BXRolandSysexHeaderLength]
                            length: length];
}

+ (NSData *) sysexWithLCDMessage: (NSString *)message
{
    //Crop/pad the message out to 20 characters
    NSString *paddedMessage = [message stringByPaddingToLength: BXMT32LCDMessageLength
                                                    withString: @" "
                                               startingAtIndex: 0];
    
    //Get a dump of the message's bytes, crushed down to ASCII encoding
    NSData *chars = [paddedMessage dataUsingEncoding: NSASCIIStringEncoding
                                allowLossyConversion: YES];
    
    UInt8 address[3] = {BXMT32SysexAddressDisplay, 0x00, 0x00};
    
    return [self sysexWithData: chars forAddress: address];
}

+ (NSData *) sysexWithData: (NSData *)data forAddress: (UInt8[3])address
{
    
    UInt8 header[BXRolandSysexHeaderLength] = {
        BXSysexStart,
        
        BXSysexManufacturerIDRoland, BXRolandSysexDeviceIDDefault, BXRolandSysexModelIDMT32,
        
        BXRolandSysexSend
    };
    
    NSUInteger finalLength = [data length] + BXRolandSysexHeaderLength + BXRolandSysexAddressLength + BXRolandSysexTailLength;
    NSMutableData *sysex = [NSMutableData dataWithCapacity: finalLength];
    
    [sysex appendBytes: header length: BXRolandSysexHeaderLength];
    [sysex appendBytes: address length: BXRolandSysexAddressLength];
    [sysex appendData: data];
    
    //Calculate the checksum based on the address and data parts of the overall sysex
    UInt8 *bytes = (UInt8 *)[sysex bytes];
    NSUInteger checksum = [self _checksumForBytes: &bytes[BXRolandSysexHeaderLength]
                                           length: (BXRolandSysexAddressLength + [data length])];
    
    UInt8 tail[BXRolandSysexTailLength] = { checksum, BXSysexEnd };
    [sysex appendBytes: tail length: BXRolandSysexTailLength];
    
    return sysex;
}

+ (NSData *) sysexRequestForDataOfLength: (NSUInteger)numBytes
                             fromAddress: (UInt8[3])address
{
    UInt8 header[BXRolandSysexHeaderLength] = {
        BXSysexStart,
        
        BXSysexManufacturerIDRoland, BXRolandSysexDeviceIDDefault, BXRolandSysexModelIDMT32,
        
        BXRolandSysexRequest
    };
    
    //Split the requested length into high, middle and low bytes in big-endian order
    UInt8 requestSize[BXRolandSysexRequestSizeLength] = {
        (numBytes & 0xFF0000) >> 16,
        (numBytes & 0x00FF00) >> 8,
        (numBytes & 0x0000FF)
    };
    
    NSMutableData *sysex = [NSMutableData dataWithCapacity: BXRolandSysexRequestLength];
    
    [sysex appendBytes: header length: BXRolandSysexHeaderLength];
    [sysex appendBytes: address length: BXRolandSysexAddressLength];
    [sysex appendBytes: requestSize length: BXRolandSysexRequestSizeLength];
    
    //Calculate the checksum based on the address and requuest size parts of the overall sysex
    UInt8 *bytes = (UInt8 *)[sysex bytes];
    NSUInteger checksum = [self _checksumForBytes: &bytes[BXRolandSysexHeaderLength]
                                           length: (BXRolandSysexAddressLength + BXRolandSysexRequestSizeLength)];
    
    UInt8 tail[BXRolandSysexTailLength] = { checksum, BXSysexEnd };
    [sysex appendBytes: tail length: BXRolandSysexTailLength];
    
    return sysex;
}

@end
