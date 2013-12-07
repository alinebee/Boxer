/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXAudio category extends BXEmulator with functionality
//for controlling DOSBox's audio emulation and output.

#import "BXEmulator.h"
#import "BXEmulatedMT32Delegate.h"


#pragma mark - MIDI device description constants

//Keys and constants used in the dictionary for requestedMIDIDeviceDescription.

/// Possible values for the BXMIDIMusicTypeKey of MIDI device description dictionaries.
/// Set by the game configuration's @c mididevice setting to determine what kind of MIDI
/// device the emulator should request.
typedef enum {
    /// The emulator should disable MIDI playback altogether.
    /// Determined by the game configuration file and is not used in descriptions
    /// when requesting a MIDI device from the delegate.
    BXMIDIMusicDisabled    = -1,

    /// The emulator should detect whether the game plays MT-32 or General MIDI music.
    /// Determined by the game configuration file and is not used in descriptions
    /// when requesting a MIDI device from the delegate.
    BXMIDIMusicAutodetect  = 0,

    /// The game plays General MIDI music.
    BXMIDIMusicGeneralMIDI = 1,
    
    /// The game plays MT-32 music.
    BXMIDIMusicMT32        = 2
} BXMIDIMusicType;

/// An NSNumber corresponding to one of the BXMIDIMusicType constants.
/// If BXMIDIMusicDisabled, Boxer will disable MIDI playback.
extern NSString * const BXMIDIMusicTypeKey;

/// An NSNumber boolean indicating whether an external General MIDI playback device
/// should be chosen if any are available.
extern NSString * const BXMIDIPreferExternalKey;

/// An NSNumber indicating the unique ID of the external device to use for MIDI playback.
/// Only applicable if @c BXMIDIPreferExternal is YES.
extern NSString * const BXMIDIExternalDeviceUniqueIDKey;

/// An NSNumber indicating the numeric enumeration order of the external device to use for MIDI playback.
/// Only applicable if @c BXMIDIPreferExternalKey is @c YES.
/// @note If both this and @c BXMIDIExternalDeviceUniqueIDKey are omitted, delegates should return the
/// first appropriate MIDI device that is found.
extern NSString * const BXMIDIExternalDeviceIndexKey;

/// An NSNumber boolean indicating whether the requested external MIDI device requires additional sysex
/// delays when sending MIDI signals. Necessary for older-generation MT-32 devices.
extern NSString * const BXMIDIExternalDeviceNeedsMT32SysexDelaysKey;


#pragma mark - BXEmulator (BXAudio)

@protocol BXMIDIDevice;
@interface BXEmulator (BXAudio) <BXEmulatedMT32Delegate>

#pragma mark - MIDI processing

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
