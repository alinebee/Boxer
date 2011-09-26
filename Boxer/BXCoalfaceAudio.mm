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

void boxer_suggestMIDIHandler(const char *handlerName)
{
    NSString *name = [[NSString stringWithCString: handlerName encoding: BXDirectStringEncoding] lowercaseString];
    
    BXMIDIDeviceType preferredType = BXMIDIDeviceTypeAuto;
    
    if      ([name isEqualToString: @"mt32"])       preferredType = BXMIDIDeviceTypeMT32;
    else if ([name isEqualToString: @"coreaudio"])  preferredType = BXMIDIDeviceTypeGeneralMIDI;
    else if ([name isEqualToString: @"coremidi"])   preferredType = BXMIDIDeviceTypeExternal;
    
    [[BXEmulator currentEmulator] setPreferredMIDIDeviceType: preferredType];
}

bool boxer_MIDIAvailable()
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator activeMIDIDevice] != nil || [emulator preferredMIDIDeviceType] != BXMIDIDeviceTypeNone;
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
