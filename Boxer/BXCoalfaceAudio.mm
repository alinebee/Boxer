/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import "BXEmulatorPrivate.h"
#import "BXCoalfaceAudio.h"
#import "RegexKitLite.h"
#import <CoreFoundation/CFByteOrder.h>

//MIDI message lengths indexed by status code.
//Copypasta from midi.cpp, modified with fixes of our own:
//only undefined status codes are marked as having a length of 0.
Bit8u BXMIDIMessageLength[256] = {
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x00
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x10
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x20
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x30
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x40
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x50
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x60
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,  // 0x70
    
    3,3,3,3, 3,3,3,3, 3,3,3,3, 3,3,3,3,  // 0x80
    3,3,3,3, 3,3,3,3, 3,3,3,3, 3,3,3,3,  // 0x90
    3,3,3,3, 3,3,3,3, 3,3,3,3, 3,3,3,3,  // 0xa0
    3,3,3,3, 3,3,3,3, 3,3,3,3, 3,3,3,3,  // 0xb0
    
    2,2,2,2, 2,2,2,2, 2,2,2,2, 2,2,2,2,  // 0xc0
    2,2,2,2, 2,2,2,2, 2,2,2,2, 2,2,2,2,  // 0xd0
    
    3,3,3,3, 3,3,3,3, 3,3,3,3, 3,3,3,3,  // 0xe0
    1,2,3,2, 0,0,1,1, 1,0,1,1, 1,0,1,1   // 0xf0
};

void boxer_suggestMIDIHandler(const char *handlerName, const char *configParams)
{
    NSString *name = [[[NSString stringWithCString: handlerName encoding: BXDirectStringEncoding]
                       stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    NSString *params = [[NSString stringWithCString: configParams encoding: BXDirectStringEncoding]
                        stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    
    
    NSMutableDictionary *description = [[NSMutableDictionary alloc] initWithCapacity: 3];
    BXMIDIMusicType musicType = BXMIDIMusicAutodetect;
    
    if ([name isEqualToString: @"none"])
    {
        musicType = BXMIDIMusicDisabled;
    }
    if ([name isEqualToString: @"mt32"])
    {
        musicType = BXMIDIMusicMT32;
    }
    else if ([name isEqualToString: @"coreaudio"])
    {
        musicType = BXMIDIMusicGeneralMIDI;
    }
    else if ([name isEqualToString: @"coremidi"])
    {
        [description setObject: [NSNumber numberWithBool: YES]
                        forKey: BXMIDIPreferExternalKey];
        
        //If the configuration parameter string starts with a number,
        //grab that as the destination index.
        if ([params isMatchedByRegex: @"^\\d+"])
        {
            NSString *indexString = [[params componentsMatchedByRegex: @"^(\\d+)" capture: 1] objectAtIndex: 0];
            NSInteger destinationIndex = [indexString integerValue];
            
            [description setObject: [NSNumber numberWithInteger: destinationIndex]
                            forKey: BXMIDIExternalDeviceIndexKey];
        }
        
        //Check for the delaysysex flag, which indicates we need to use
        //sysex delays suitable for older MT-32s when talking to the device.
        if ([params isMatchedByRegex: @"delaysysex"])
        {
            [description setObject: [NSNumber numberWithBool: YES]
                            forKey: BXMIDIExternalDeviceNeedsMT32SysexDelaysKey];
        }
    }
    
    [description setObject: [NSNumber numberWithInteger: musicType] forKey: BXMIDIMusicTypeKey];
    
    [[BXEmulator currentEmulator] setRequestedMIDIDeviceDescription: description];
    
    [description release];
}

bool boxer_MIDIAvailable()
{
    //Always treat MIDI as available, even if we're using a dummy MIDI handler.
    //(This actually matches DOSBox's behaviour.)
    return YES;
}

void boxer_sendMIDIMessage(Bit8u *msg)
{
    //Look up how long the total message is expected to be, based on the status code.
    Bit8u status = msg[0];
    NSUInteger len = (NSUInteger)BXMIDIMessageLength[status];
    
    if (len)
    {
        [[BXEmulator currentEmulator] sendMIDIMessage: [NSData dataWithBytesNoCopy: msg length: len freeWhenDone: NO]];
    }    
#ifdef BOXER_DEBUG
    //DOSBox's MIDI event table declares undefined MIDI statuses as having 0 length.
    //Such messages should not be passed onwards, but should be logged.
    //q.v.: http://www.midi.org/techspecs/midimessages.php
    else
    {
        NSLog(@"Undefined MIDI message received: status code %0x", status);
    }
#endif
}

void boxer_sendMIDISysex(Bit8u *msg, Bitu len)
{
    [[BXEmulator currentEmulator] sendMIDISysex: [NSData dataWithBytesNoCopy: msg length: len freeWhenDone: NO]];
}

float boxer_masterVolume(BXAudioChannel channel)
{
    return [[BXEmulator currentEmulator] _masterVolumeForChannel: channel];
}
