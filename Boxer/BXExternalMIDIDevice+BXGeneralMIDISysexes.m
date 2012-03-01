//
//  BXExternalMIDIDevice+BXGeneralMIDISysexes.m
//  Boxer
//
//  Created by Alun Bestor on 01/03/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXExternalMIDIDevice+BXGeneralMIDISysexes.h"

@implementation BXExternalMIDIDevice (BXGeneralMIDISysexes)

+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (float *)volume
{
    //The wrong size for a volume sysex, don't bother continuing
    if (sysex.length != 8) return NO;
    
    UInt8 *content = (UInt8 *)sysex.bytes;
    UInt8 expectedHeader[5] = {
        BXSysexStart,
        BXGeneralMIDISysexRealtime,
        BXGeneralMIDISysexAllChannels,
        BXGeneralMIDISysexDeviceControl,
        BXGeneralMIDISysexMasterVolume
    };
    
    BOOL isMasterVolumeSysex = YES;
    NSUInteger i;
    for (i=0; i < 5; i++)
    {
        if (expectedHeader[i] != content[i]) { isMasterVolumeSysex = NO; break; }
    }
    
    //If we got this far, it is indeed a volume sysex:
    //populate the volume if provided.
    if (volume)
    {
        UInt8 volumeLowByte     = content[5];
        UInt8 volumeHighByte    = content[6];
        
        NSUInteger intVolume = volumeLowByte + (volumeHighByte << 7);
        *volume = intVolume / (float)BXGeneralMIDIMaxMasterVolume;
    }
    
    return isMasterVolumeSysex;
}

+ (NSData *) sysexWithMasterVolume: (float)volume
{
    volume = MIN(1.0f, volume);
    volume = MAX(0.0f, volume);
    
    //General MIDI master volume sysex takes a 14-bit volume,
    //which we have to split across 2 bytes using 7 bits in each byte.
    NSUInteger intVolume = (NSUInteger)round(volume * BXGeneralMIDIMaxMasterVolume);
    
    UInt8 volumeLowByte     = intVolume & BXMIDIBitmask;
    UInt8 volumeHighByte    = (intVolume >> 7) & BXMIDIBitmask;
    
    const UInt8 sysexBytes[8] = {
        BXSysexStart,
        BXGeneralMIDISysexRealtime,
        BXGeneralMIDISysexAllChannels,
        BXGeneralMIDISysexDeviceControl,
        BXGeneralMIDISysexMasterVolume,
        
        volumeLowByte,
        volumeHighByte,
        
        BXSysexEnd
    };

    NSData *sysex = [NSData dataWithBytes: sysexBytes length: 8];
    return sysex;
}

@end
