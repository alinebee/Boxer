/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXExternalMT32.h"

/// Helper methods for generating MIDI sysex messages for the MT-32.
@interface BXExternalMT32 (BXMT32Sysexes)

/// Calculates and returns the proper checksum for the specified MT-32 sysex.
/// Returns NSNotFound if a checksum cannot be calculated for the sysex
/// (e.g. if the sysex is too short.)
+ (NSUInteger) checksumForSysex: (NSData *)sysex;

/// Returns an MT-32 sysex to send the specified data to the specified address.
+ (NSData *) sysexWithData: (NSData *)data forAddress: (UInt8[3])address;

/// Returns an MT-32 sysex to request the specified number of bytes from the specified address.
+ (NSData *) sysexRequestForDataOfLength: (NSUInteger)numBytes
                             fromAddress: (UInt8[3])address;

/// Returns an MT-32 sysex that can be used to display the specified LCD message.
+ (NSData *) sysexWithLCDMessage: (NSString *)message;

/// Returns the data payload of the specified sysex, or \c nil if it was not valid.
/// If \c includeAddress is <code>YES</code>, the 3-byte address prefix will be included in the
/// returned data also.
+ (NSData *) dataInSysex: (NSData *)sysex
        includingAddress: (BOOL)includeAddress;


/// Returns \c YES if the specified sysex message is intended for an MT-32 and, if provided,
/// whether it matches the specified address.
/// If \c isRequest is specified, this will be populated with \c YES if the sysex is a request
/// message or \c NO if it is a send message.
+ (BOOL) isMT32Sysex: (NSData *)sysex matchingAddress: (UInt8[3])address isRequest: (BOOL *)isRequest;

/// Returns \c YES if the specified sysex message is intended for an MT-32,
/// \c NO otherwise.
/// If \c confirmsSupport is provided, this will be set to \c YES if the
/// message indicates that the game sending it will definitely provide
/// music tailored to the MT-32, or \c NO if it's inconclusive.
+ (BOOL) isMT32Sysex: (NSData *)sysex
   confirmingSupport: (BOOL *)supportConfirmed;


/// Returns whether the specified sysex is an attempt to set the master volume.
/// If it is and volume is specified, volume will be populated with the master volume
/// in the sysex (from 0.0 to 1.0.)
///
/// Note that this overrides the parent implementation in <code>BXGeneralMIDISysexes</code>.
+ (BOOL) isMasterVolumeSysex: (NSData *)sysex withVolume: (float *)volume;

/// Returns whether the specified sysex will reset the master volume to its default value.
///
/// Note that this overrides the parent implementation in <code>BXGeneralMIDISysexes</code>.
+ (BOOL) sysexResetsMasterVolume: (NSData *)sysex;

/// Returns an MT-32 sysex that can be used to set the specified volume (from 0.0f to 1.0f.)
///
/// Note that this overrides the parent implementation in <code>BXGeneralMIDISysexes</code>.
+ (NSData *) sysexWithMasterVolume: (float)volume;

@end
