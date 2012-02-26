/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCoalface.h"

typedef enum {
    BXLeftChannel,
    BXRightChannel
} BXAudioChannel;

//Tell BXEmulator the preferred MIDI handler according to the DOSBox configuration.
void boxer_suggestMIDIHandler(const char *handlerName, const char *configParams);

//Tells DOSBox whether MIDI is currently available or not.
bool boxer_MIDIAvailable();

//Dispatch MIDI messages sent from DOSBox's MPU-401 emulation.
void boxer_sendMIDIMessage(Bit8u *msg);
void boxer_sendMIDISysex(Bit8u *msg, Bitu len);

float boxer_masterVolume(BXAudioChannel channel);

//Defined in mixer.cpp. Update the volumes of all active channels.
void boxer_updateVolumes();