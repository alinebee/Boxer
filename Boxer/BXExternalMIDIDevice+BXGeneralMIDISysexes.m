/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMIDIDevice+BXGeneralMIDISysexes.h"

@implementation BXExternalMIDIDevice (BXGeneralMIDISysexes)

+ (BOOL) sysexResetsMasterVolume: (NSData *)sysex
{
    //TODO: find out if there are any official General MIDI parameters
    //for resetting device parameters to defaults.
    return NO;
}

+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (float *)volume
{
    //The wrong size for a volume sysex, don't bother continuing
    if (sysex.length != 8) return NO;
    
    //Compare the headers of the sysex to what we expect to find.
    UInt8 *content = (UInt8 *)sysex.bytes;
    UInt8 expectedHeader[5] = {
        BXSysexStart,
        BXGeneralMIDISysexRealtime,
        0x00, //Allow any value for the device ID
        BXGeneralMIDISysexDeviceControl,
        BXGeneralMIDISysexMasterVolume
    };
    
    NSUInteger i;
    for (i=0; i < 5; i++)
    {
        if (expectedHeader[i] && (expectedHeader[i] != content[i])) return NO;
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
    
    return YES;
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
