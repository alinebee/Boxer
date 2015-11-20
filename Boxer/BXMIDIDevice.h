/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXMIDIDevice protocol defines an interface for emulated (and not-so-emulated)
//MIDI devices, to which BXEmulator can send MIDI output.

#import <Foundation/Foundation.h>
#import "BXMIDIConstants.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Protocol declaration

@protocol BXMIDIDevice <NSObject>

#pragma mark -
#pragma mark Properties

//! The master volume of the MIDI device from \c 0.0 to \c 1.0, independent of the volume
//! of individual channels. MIDI devices are not expected to support fine-grained
//! volume control, but at the very least should mute themselves when their volume
//! is set to 0.
@property (nonatomic, readwrite) float volume;

//! Returns whether this device can play back MT-32 music properly.
- (BOOL) supportsMT32Music;

//! Returns whether this device can play back General MIDI music properly.
- (BOOL) supportsGeneralMIDIMusic;

//! Returns whether this device is still processing events.
//! If <code>YES</code>, further messages should not be sent until <code>dateWhenReady</code>.
@property (readonly, getter=isProcessing) BOOL processing;

//! The date at which this device will next be able to receive events.
//! Sending events before this may result in skipped or truncated messages.
- (NSDate *) dateWhenReady;


#pragma mark -
#pragma mark Instance methods

//! Handle a standard MIDI message, which will be between 1 and 3
//! bytes long depending on the type of message.
- (void) handleMessage: (NSData *)message;

//! Handle a System Exclusive message of arbitrary length.
- (void) handleSysex: (NSData *)message;

//! Pause/resume MIDI playback.
- (void) pause;
- (void) resume;

//! Close down the connection and free up all resources.
//! Should be called by dealloc, but may be called sooner manually.
//! After this has been called, the MIDI device is expected to be
//! in an unusable state.
- (void) close;

@end

NS_ASSUME_NONNULL_END
