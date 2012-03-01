/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXMIDISyth sending MIDI signals from DOSBox to OS X's built-in MIDI synth, using the AUGraph API.
//It's largely cribbed from DOSBox's own coreaudio MIDI handler.

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "BXMIDIDevice.h"

@class BXEmulator;
@interface BXMIDISynth : NSObject <BXMIDIDevice>
{
	AUGraph _graph;
	AudioUnit _synthUnit;
	AudioUnit _outputUnit;
    NSString *_soundFontPath;
}

//The path to the soundfont bank we are currently using,
//or nil if no soundfont is in use.
//Must be set with loadSoundFontAtPath:error:
@property (readonly, copy, nonatomic) NSString *soundFontPath;

//Returns a fully-initialized synth ready to receive MIDI messages.
//Returns nil and populates outError if the synth could not be initialised.
- (id <BXMIDIDevice>) initWithError: (NSError **)outError;

//Sets the specified soundfont with which MIDI should be played back.
//soundFontPath will be updated with the specified path.
//Pass nil as the path to clear a previous soundfont.
//Returns YES if the soundfont was loaded/cleared, or NO and populates
//outError if the soundfont couldn't be loaded for any reason (in which
//case soundFontPath will remain unchanged.)
- (BOOL) loadSoundFontAtPath: (NSString *)path error: (NSError **)outError;

@end
