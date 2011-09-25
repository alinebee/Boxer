/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXAudio category extends BXEmulator with functionality
//for controlling DOSBox's audio emulation and output.

#import "BXEmulator.h"
#import "BXEmulatedMT32Delegate.h"

@protocol BXMIDIDevice;
@interface BXEmulator (BXAudio) <BXEmulatedMT32Delegate>


//Sends an LCD message via Sysex to the MT-32 emulator
//(or to a real MT-32, in CoreMIDI mode.)
//Intended for debugging.
- (id) displayMT32LCDMessage: (NSString *)message;

//Creates a new MIDI device of the specified type, ready for use by the emulator
//but not assigned as the active device.
- (id <BXMIDIDevice>) MIDIDeviceForType: (BXMIDIDeviceType)type error: (NSError **)outError;

//Attach a new active MIDI device of the specified type.
//Returns YES if the device was initialized and attached successfully,
//or NO and populates outError if the device could not be created.
- (BOOL) attachMIDIDeviceOfType: (BXMIDIDeviceType)type error: (NSError **)outError;

- (void) sendMIDIMessage: (uint8_t *)message length: (NSUInteger)length;
- (void) sendMIDISysEx: (uint8_t *)message length: (NSUInteger)length;

//Returns YES if the specified sysex message is explicitly intended
//for a Roland MT-32, NO otherwise.
- (BOOL) isMT32SysEx: (uint8_t *)message length: (NSUInteger)length;
@end
