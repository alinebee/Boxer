/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXAudioControls category manages BXEmulator's audio subsystem and will eventually
//expose controls for audio output.

#import "BXSession.h"

@interface BXSession (BXAudioControls) <BXEmulatorAudioDelegate>

//Returns whether the specified MIDI device is suitable for the specified description.
//Used for choosing whether to stick with the current MIDI device or create a new one.
- (BOOL) MIDIDevice: (id <BXMIDIDevice>)device meetsDescription: (NSDictionary *)description;
@end
