/*
 *  Copyright (C) 2002-2009  The DOSBox Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AudioToolbox/AUGraph.h>
#include <AvailabilityMacros.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
#define OS_X_10_5
#endif


// A macro to simplify error handling a bit.
#define RequireNoErr(error)                                         \
do {                                                                \
	err = error;                                                    \
	if (err != noErr)                                               \
		goto bail;                                                  \
} while (false)

class MidiHandler_coreaudio : public MidiHandler {
private:
	AUGraph m_auGraph;
	AudioUnit m_synth;
public:
	MidiHandler_coreaudio() : m_auGraph(0), m_synth(0) {}
	const char * GetName(void) { return "coreaudio"; }
	bool Open(const char * conf) {
		OSStatus err = 0;

		if (m_auGraph)
			return false;

		// Open the Music Device.
		RequireNoErr(NewAUGraph(&m_auGraph));

		AUNode outputNode, synthNode;
		ComponentDescription desc;

		// The default output device
		desc.componentType = kAudioUnitType_Output;
		desc.componentSubType = kAudioUnitSubType_DefaultOutput;
		desc.componentManufacturer = kAudioUnitManufacturer_Apple;
		desc.componentFlags = 0;
		desc.componentFlagsMask = 0;

#ifdef OS_X_10_5
		RequireNoErr(AUGraphAddNode(m_auGraph, &desc, &outputNode));
#else
		RequireNoErr(AUGraphNewNode(m_auGraph, &desc, 0, NULL, &outputNode));
#endif
		
		// The built-in default (softsynth) music device
		desc.componentType = kAudioUnitType_MusicDevice;
		desc.componentSubType = kAudioUnitSubType_DLSSynth;
		desc.componentManufacturer = kAudioUnitManufacturer_Apple;
		RequireNoErr(AUGraphAddNode(m_auGraph, &desc, &synthNode));

#ifdef OS_X_10_5
		RequireNoErr(AUGraphAddNode(m_auGraph, &desc, &synthNode));
#else
		RequireNoErr(AUGraphNewNode(m_auGraph, &desc, 0, NULL, &synthNode));
#endif
		
		// Connect the softsynth to the default output
		RequireNoErr(AUGraphConnectNodeInput(m_auGraph, synthNode, 0, outputNode, 0));

		// Open and initialize the whole graph
		RequireNoErr(AUGraphOpen(m_auGraph));
		RequireNoErr(AUGraphInitialize(m_auGraph));

		// Get the music device from the graph.
#ifdef OS_X_10_5
		RequireNoErr(AUGraphNodeInfo(m_auGraph, synthNode, NULL, &m_synth));
#else
		RequireNoErr(AUGraphGetNodeInfo(m_auGraph, synthNode, NULL, NULL, NULL, &m_synth));
#endif
		
		// Finally: Start the graph!
		RequireNoErr(AUGraphStart(m_auGraph));

		return true;

	bail:
		if (m_auGraph) {
			AUGraphStop(m_auGraph);
			DisposeAUGraph(m_auGraph);
			m_auGraph = 0;
		}
		return false;
	}

	void Close(void) {
		if (m_auGraph) {
			AUGraphStop(m_auGraph);
			DisposeAUGraph(m_auGraph);
			m_auGraph = 0;
		}
	}

	void PlayMsg(Bit8u * msg) {
		MusicDeviceMIDIEvent(m_synth, msg[0], msg[1], msg[2], 0);
	}	

	void PlaySysex(Bit8u * sysex, Bitu len) {
		MusicDeviceSysEx(m_synth, sysex, len);
	}
	
	//--Added 2009-03-11 by Alun Bestor to allow Boxer to mute/unmute MIDI output
	//Note that this isn't actually muting it, it's pausing it
	void boxer_mute(void)	{ if (m_auGraph) AUGraphStop(m_auGraph); }
	void boxer_unmute(void)	{ if (m_auGraph) AUGraphStart(m_auGraph); }
	//--End of modifications
};

#undef RequireNoErr

MidiHandler_coreaudio Midi_coreaudio;
