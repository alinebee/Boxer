/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMT32+BXMT32Sysexes.h"


@implementation BXExternalMT32 (BXMT32Sysexes)

#pragma mark -
#pragma mark Helper class methods

+ (BOOL) isMT32Sysex: (NSData *)sysex confirmingSupport: (BOOL *)supportConfirmed
{
    BOOL isRequest = NO;
    
    //Sysex was malformed, too short, or intended for a device other than the MT-32.
    if (![self isMT32Sysex: sysex matchingAddress: NULL isRequest: &isRequest])
        return NO;
    
    //If we got this far, it's a valid MT-32 sysex: check if it confirms MT-32 support.
    if (supportConfirmed)
    {   
        //Sysex requests indicate the device is expecting a response from the MT-32:
        //treat them as confirming support.
        if (isRequest)
        {
            *supportConfirmed = YES;
        }
        //Otherwise, check what address the sysex is targeting.
        else
        {
            const UInt8 *contents = (const UInt8 *)sysex.bytes;
            UInt8 baseAddress = contents[5];
            
            //Some General MIDI drivers (used by Origin and Westwood among others)
            //send sysexes telling the MT-32 to reset and setting up initial reverb
            //and volume settings: but will then proceed to deliver General MIDI music
            //to the MT-32 anyway.
            if (baseAddress == BXMT32SysexAddressReset || baseAddress == BXMT32SysexAddressSystemArea)
            {
                *supportConfirmed = NO;
            }
            
            //7th Guest menu music and Strike Commander eject music attempt to send short messages
            //to patch memory even in General MIDI mode, so we catch these and treat them as inconclusive.
            else if (baseAddress == BXMT32SysexAddressPatchMemory && (sysex.length == 11 || sysex.length == 12))
            {
                *supportConfirmed = NO;
            }
            
            //If an LCD message is sent, check the contents to see if it matches messages we know to ignore.
            else if (baseAddress == BXMT32SysexAddressDisplay)
            {
                NSData *messageData = [self dataInSysex: sysex includingAddress: NO];
                NSString *LCDMessage = [[NSString alloc] initWithData: messageData
                                                             encoding: NSASCIIStringEncoding];
                
                NSArray *ignoredMessages = [NSArray arrayWithObjects:
                                            //Sent by Pacific Strike and Strike Commander in General MIDI mode
                                            @"SCSCSCFY!           ",
                                            @"Bye.                ",
                                            nil];
                
                *supportConfirmed = (![ignoredMessages containsObject: LCDMessage]);
                [LCDMessage release];
            }
            
            //Otherwise, assume it confirms support.
            else *supportConfirmed = YES;
        }
    }
    
    return YES;
}

+ (NSData *) dataInSysex: (NSData *)sysex includingAddress: (BOOL)includeAddress
{
    if (sysex.length < BXRolandSysexSendMinLength) return nil;
    
    NSUInteger startOffset = BXRolandSysexHeaderLength;
    if (!includeAddress) startOffset += BXRolandSysexAddressLength;
    NSUInteger endOffset = sysex.length - BXRolandSysexTailLength;
    
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
    if (sysex.length < (BXRolandSysexHeaderLength + BXRolandSysexTailLength))
        return NSNotFound;
    
    //The checksum for a Roland sysex message is calculated from
    //the bytes of the message address and the message data:
    //skip the bytes before and after that block.
    UInt8 *bytes = (UInt8 *)sysex.bytes;
    
    NSUInteger length = sysex.length - BXRolandSysexHeaderLength - BXRolandSysexTailLength;
    
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
    
    NSUInteger finalLength = data.length + BXRolandSysexHeaderLength + BXRolandSysexAddressLength + BXRolandSysexTailLength;
    NSMutableData *sysex = [NSMutableData dataWithCapacity: finalLength];
    
    [sysex appendBytes: header length: BXRolandSysexHeaderLength];
    [sysex appendBytes: address length: BXRolandSysexAddressLength];
    [sysex appendData: data];
    
    //Calculate the checksum based on the address and data parts of the overall sysex
    UInt8 *bytes = (UInt8 *)sysex.bytes;
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
        (numBytes >> 14)    & BXMIDIBitmask,
        (numBytes >> 7)     & BXMIDIBitmask,
        (numBytes)          & BXMIDIBitmask
    };
    
    NSMutableData *sysex = [NSMutableData dataWithCapacity: BXRolandSysexRequestLength];
    
    [sysex appendBytes: header length: BXRolandSysexHeaderLength];
    [sysex appendBytes: address length: BXRolandSysexAddressLength];
    [sysex appendBytes: requestSize length: BXRolandSysexRequestSizeLength];
    
    //Calculate the checksum based on the address and request size parts of the overall sysex
    UInt8 *bytes = (UInt8 *)sysex.bytes;
    NSUInteger checksum = [self _checksumForBytes: &bytes[BXRolandSysexHeaderLength]
                                           length: (BXRolandSysexAddressLength + BXRolandSysexRequestSizeLength)];
    
    UInt8 tail[BXRolandSysexTailLength] = { checksum, BXSysexEnd };
    [sysex appendBytes: tail length: BXRolandSysexTailLength];
    
    return sysex;
}

+ (BOOL) isMT32Sysex: (NSData *)sysex matchingAddress: (UInt8[3])address isRequest: (BOOL *)isRequest
{
    //Sysex is too short, reject immediately
    if (sysex.length < BXRolandSysexSendMinLength) return NO;
    
    UInt8 *content = (UInt8 *)sysex.bytes;
    if (content[1] != BXSysexManufacturerIDRoland) return NO;
    if (content[3] != BXRolandSysexModelIDMT32  && content[3] != BXRolandSysexModelIDD50) return NO;
    if (content[4] != BXRolandSysexRequest      && content[4] != BXRolandSysexSend) return NO;
    
    //If a specified address was provided, check against that too
    if (address)
    {
        if (content[5] != address[0]) return NO;
        if (content[6] != address[1]) return NO;
        if (content[7] != address[2]) return NO;
    }
    
    //If we got this far, the sysex is OK: populate isRequest if provided.
    if (isRequest)
    {
        *isRequest = (content[4] == BXRolandSysexRequest);
    }
    
    return YES;
}

+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (float *)volume
{
    //Reject the sysex if it is the wrong size for a master volume sysex.
    if (sysex.length != BXRolandSysexSendMinLength + 1) return NO;
    
    //Reject the sysex if it is not an MT-32 send message addressing the master volume.
    UInt8 expectedAddress[3] = {BXMT32SysexAddressSystemArea, 0x00, 0x16};
    BOOL isRequest = NO;
    if (!([self isMT32Sysex: sysex matchingAddress: expectedAddress isRequest: &isRequest] && !isRequest))
        return NO;
    
    //If we got this far, it is indeed a volume sysex:
    //populate the volume if it was requested.
    if (volume)
    {
        NSUInteger intVolume = ((UInt8 *)sysex.bytes)[8];
        *volume = intVolume / (float)BXMT32MaxMasterVolume;
    }
    
    return YES;
}

+ (BOOL) sysexResetsMasterVolume: (NSData *)sysex
{
    BOOL isRequest = NO;
    
    //Ignore messages other than MT-32 send sysexes.
    if (![self isMT32Sysex: sysex matchingAddress: NULL isRequest: &isRequest] || isRequest)
        return NO;
    
    UInt8 *content = (UInt8 *)sysex.bytes;
    UInt8 baseAddress = content[5];
    UInt8 subAddress1 = content[6];
    UInt8 subAddress2 = content[7];
    
    //Setting master tune appears to reset the master volume.
    if (baseAddress == BXMT32SysexAddressSystemArea && subAddress1 == 0x00 && subAddress2 == 0x00)
        return YES;
    
    return NO;
}

+ (NSData *) sysexWithMasterVolume: (float)volume
{
    volume = MIN(1.0f, volume);
    volume = MAX(0.0f, volume);
    UInt8 intVolume = (UInt8)roundf(volume * BXMT32MaxMasterVolume) & BXMIDIBitmask;
    
    NSData *data        = [NSData dataWithBytes: &intVolume length: 1];
    UInt8 address[3]    = {BXMT32SysexAddressSystemArea, 0x00, 0x16};
    
    return [self sysexWithData: data forAddress: address];
}

@end
