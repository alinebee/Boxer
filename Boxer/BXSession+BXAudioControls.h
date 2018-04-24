/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSession.h"

/// The \c BXAudioControls category manages delegate responses to BXEmulator's audio subsystem.
@interface BXSession (BXAudioControls) <BXEmulatorAudioDelegate>

/// Returns whether the specified MIDI device is suitable for the specified description.
/// Used for choosing whether to stick with the current MIDI device or create a new one.
- (BOOL) MIDIDevice: (id <BXMIDIDevice>)device meetsDescription: (NSDictionary *)description;

@end
