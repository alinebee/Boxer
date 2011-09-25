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

extern Bit8u MIDI_evt_len[256];

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
    //Look up how long the message is expected to be, based on the type of message.
    NSUInteger len = MIDI_evt_len[*msg];
    [[BXEmulator currentEmulator] sendMIDIMessage: msg length: len];
}

void boxer_sendMIDISysEx(Bit8u *msg, Bit8u len)
{
    [[BXEmulator currentEmulator] sendMIDISysEx: msg length: len];
}
