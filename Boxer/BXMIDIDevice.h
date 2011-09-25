/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXMIDIDevice protocol defines an interface for emulated (and not-so-emulated)
//MIDI devices, to which BXEmulator can send MIDI output.

#import <Foundation/Foundation.h>


#pragma mark -
#pragma mark Helper constants for MIDI devices

#define BXSysExStart 0xF0
#define BXSysExEnd 0xF7

#define BXChannelModeChangePrefix 0xB0
#define BXAllNotesOffMessage 0x7B


#pragma mark -
#pragma mark Protocol declaration

@protocol BXMIDIDevice <NSObject>

#pragma mark -
#pragma mark Instance methods

//Handle a standard MIDI message, which will be between 1 and 3 bytes
//long depending on the type of message.
- (void) handleMessage: (const UInt8 *)message
                length: (NSUInteger)length;

//Play a System Exclusive message of arbitrary length.
- (void) handleSysex: (const UInt8 *)message
              length: (NSUInteger)length;

//Pause/resume MIDI playback.
- (void) pause;
- (void) resume;

@end
