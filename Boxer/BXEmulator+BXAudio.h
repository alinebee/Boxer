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

#pragma mark -
#pragma mark Helper class methods

//Returns YES if the specified sysex message is explicitly intended
//for a Roland MT-32, NO otherwise.
//If indicatesSupport is provided, this will be set to YES if the
//message indicates the game will provide music tailored to the MT-32,
//NO if it's inconclusive.
+ (BOOL) isMT32Sysex: (NSData *)message indicatingMT32Support: (BOOL *)indicatesSupport;

//Returns YES if the specified sysex message is a generic message
//expected to be supported by any General MIDI-compliant device,
//or NO if it is manufacturer-specific (or not a valid sysex.)
+ (BOOL) isGeneralMIDISysex: (NSData *)message;


#pragma mark -
#pragma mark MIDI processing

//Sends an LCD message via Sysex to the MT-32 emulator
//(or to a real MT-32, in CoreMIDI mode.)
//Intended for debugging.
- (void) sendMT32LCDMessage: (NSString *)message;

//Creates a new MIDI device of the specified type, ready for use by the emulator
//but not assigned as the active device.
- (id <BXMIDIDevice>) MIDIDeviceForType: (BXMIDIDeviceType)type error: (NSError **)outError;

//Attach a new active MIDI device of the specified type.
//Returns the newly-attached device if it was initialized and attached successfully,
//or nil and populates outError if the device could not be created.
- (id <BXMIDIDevice>) attachMIDIDeviceOfType: (BXMIDIDeviceType)type error: (NSError **)outError;

//Dispatch the specified MIDI message/sysex onward to the active MIDI device.
- (void) sendMIDIMessage: (NSData *)message;
- (void) sendMIDISysex: (NSData *)message;

@end
