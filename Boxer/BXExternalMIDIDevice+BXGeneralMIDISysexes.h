/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXExternalMIDIDevice.h"

NS_ASSUME_NONNULL_BEGIN

//Helper methods for generating MIDI sysex messages for General MIDI devices.

@interface BXExternalMIDIDevice (BXGeneralMIDISysexes)

//Returns whether the specified sysex is a request to set the master volume.
//If it is and volume is specified, volume will be populated with the master volume
//in the sysex (from 0.0 to 1.0.)
+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (nullable float *)volume;

//Returns a General MIDI sysex that can be used to set the specified master volume (from 0.0f to 1.0f.)
+ (NSData *) sysexWithMasterVolume: (float)volume;

//Returns whether the specified sysex will reset the master volume to its default value.
//The base implementation returns NO: it is intended to be overridden by subclasses
//to define device-specific messages.
+ (BOOL) sysexResetsMasterVolume: (NSData *)sysex;
@end

NS_ASSUME_NONNULL_END
