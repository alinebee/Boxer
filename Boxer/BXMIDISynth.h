/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXMIDISyth sending MIDI signals from DOSBox to OS X's built-in MIDI synth, using the AUGraph API.
//It's largely cribbed from DOSBox's own coreaudio MIDI handler.

#import "BXMIDIDevice.h"
#import <AudioToolbox/AudioToolbox.h>

@class BXEmulator;
@interface BXMIDISynth : NSObject <BXMIDIDevice>
{
	AUGraph _graph;
	AudioUnit _synthUnit;
	AudioUnit _outputUnit;
    NSURL *_soundFontURL;
}

//The URL of the soundfont bank we are currently using,
//which be the default system unless a custom one has been
//set with loadSoundFontWithContentsOfURL:error:
@property (readonly, copy, nonatomic) NSURL *soundFontURL;

//Returns the URL of the default system soundfont.
+ (NSURL *) defaultSoundFontURL;

//Returns a fully-initialized synth ready to receive MIDI messages.
//Returns nil and populates outError if the synth could not be initialised.
- (id <BXMIDIDevice>) initWithError: (NSError **)outError;

//Sets the specified soundfont with which MIDI should be played back.
//soundFontURL will be updated with the specified URL.
//Pass nil as the path to clear a previous custom soundfont and revert
//to using the system soundfont.
//Returns YES if the soundfont was loaded/cleared, or NO and populates
//outError if the soundfont couldn't be loaded for any reason (in which
//case soundFontURL will remain unchanged.)
- (BOOL) loadSoundFontWithContentsOfURL: (NSURL *)URL error: (NSError **)outError;

@end
