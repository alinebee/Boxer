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


#pragma mark -
#pragma mark Constants

//Keys and constants used in the dictionary for requestedMIDIDeviceDescription.

enum {
    BXMIDIMusicDisabled    = -1,    //Disable MIDI playback altogether.
    BXMIDIMusicAutodetect  = 0,     //Autodetect whether the game plays MT-32 or General MIDI music
    BXMIDIMusicGeneralMIDI = 1,     //The game plays General MIDI music
    BXMIDIMusicMT32        = 2      //The game plays MT-32 music
};
typedef NSInteger BXMIDIMusicType;

//An NSNumber corresponding to one of the BXMIDIMusicType constants.
//If BXMIDIMusicNone, Boxer will disable MIDI playback.
//If omitted, defaults to BXMIDIMusicAuto.
extern NSString * const BXMIDIMusicTypeKey;

//An NSNumber containing a boolean indicating whether an external
//playback device should be used if any are available.
extern NSString * const BXMIDIPreferExternalKey;

//An NSNumber indicating the numeric destination index of the external
//device to use for MIDI playback. If omitted, defaults to 0 (which
//means the first device found).
//Only used if BXMIDIPreferExternal is YES.
extern NSString * const BXMIDIExternalDeviceIndexKey;

//An NSNumber indicating the unique ID index of the external device
//to use for MIDI playback. Takes priority over BXMIDIExternalDeviceIndex.
//Only used if BXMIDIPreferExternal is YES.
extern NSString * const BXMIDIExternalDeviceUniqueIDKey;

//An NSNumber containing a boolean indicating whether the requested
//external MIDI device needs sysex delays. (Note that this is distinct
//from the BXMIDIMusicMT32 music type.)
extern NSString * const BXMIDIExternalDeviceNeedsMT32SysexDelaysKey;


#pragma mark -
#pragma mark Interface declaration

@protocol BXMIDIDevice;
@interface BXEmulator (BXAudio) <BXEmulatedMT32Delegate>

#pragma mark -
#pragma mark MIDI processing

//Sends an LCD message via Sysex to the MT-32 emulator
//(or to a real MT-32, in CoreMIDI mode.)
//Intended for debugging.
- (void) sendMT32LCDMessage: (NSString *)message;

//Attach a new active MIDI device suitable for the specified description.
//Returns the newly-attached device if it was initialized and attached successfully,
//or nil if the device could not be created.
- (id <BXMIDIDevice>) attachMIDIDeviceForDescription: (NSDictionary *)description;

//Dispatch the specified MIDI message/sysex onward to the active MIDI device.
- (void) sendMIDIMessage: (NSData *)message;
- (void) sendMIDISysex: (NSData *)message;

@end
